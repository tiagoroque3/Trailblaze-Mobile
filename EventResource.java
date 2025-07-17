package pt.unl.fct.di.apdc.trailblaze.resources;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import com.google.cloud.datastore.*;
import com.google.cloud.datastore.StructuredQuery.PropertyFilter;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.jsonwebtoken.Claims;
import java.util.*;
import java.util.stream.*;
import pt.unl.fct.di.apdc.trailblaze.util.*;

/**
 * CRUD de eventos ligados a folhas de obra.
 * • SYSBO / SYSADMIN ⇒ cria, edita, apaga eventos e consulta inscrições
 * • RU              ⇒ inscreve-se / consulta eventos em que está inscrito
 * • Todos os utilizadores autenticados podem ver a lista completa
 */
@Path("/events")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class EventResource {

    /* --------------------- Datastore --------------------- */
    private static final Datastore  DS       = DatastoreOptions.getDefaultInstance().getService();
    private static final KeyFactory KF_EVENT = DS.newKeyFactory().setKind("Event");
    private static final KeyFactory KF_REG   = DS.newKeyFactory().setKind("EventReg");
    private static final ObjectMapper MAPPER = new ObjectMapper();

    /* ======================== Helpers JWT ======================== */

    /** Extrai o JWT de um header "Authorization". Retorna {@code null} se ausente. */
    private static String jwt(String hdr) {
        return hdr != null && hdr.startsWith("Bearer ") ? hdr.substring(7) : null;
    }

    /** Converte as claims «roles» (lista) ou «role» (legado) em lista de strings. */
    private static List<String> roles(String token) {
        try {
            Claims c   = JwtUtil.validateToken(token).getBody();
            Object raw = c.get("roles");
            if (raw instanceof List<?> list && !list.isEmpty())
                return list.stream().map(String::valueOf).collect(Collectors.toList());
            String legacy = c.get("role", String.class);
            return legacy == null ? List.of() : List.of(legacy);
        } catch (Exception e) {
            return List.of();
        }
    }

    /** Username (subject) do JWT. */
    private static String username(String token) {
        return JwtUtil.getUsername(token);
    }

    /** @return {@code true} se o utilizador tiver privilégio SYSADMIN ou SYSBO. */
    private static boolean isElevated(List<String> roles) {
        return roles.contains("SYSADMIN") || roles.contains("SYSBO");
    }

    /* ------------------------ Geo utils ------------------------- */
    private static double toRadians(double deg) { return deg * Math.PI / 180.0; }

    /** Distância aproximada (km) usando fórmula de Haversine. */ 
    private static double haversine(double lat1, double lon1, double lat2, double lon2) { 
        final double R = 6371.0; // raio médio da Terra em km 
        double dLat = toRadians(lat2 - lat1); 
        double dLon = toRadians(lon2 - lon1); 
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + 
                   Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * 
                   Math.sin(dLon / 2) * Math.sin(dLon / 2); 
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)); 
    }

    /* ------------------------ Worksheet polygons ---------------------- */
    private static ArrayNode polygonsOf(String wsId) {
        ArrayNode arr = MAPPER.createArrayNode();
        try {
            long id = Long.parseLong(wsId);
            Key wsKey = DS.newKeyFactory().setKind("WorkSheet").newKey(id);
            Query<Entity> q = Query.newEntityQueryBuilder()
                    .setKind("Parcel")
                    .setFilter(PropertyFilter.hasAncestor(wsKey))
                    .build();
            DS.run(q).forEachRemaining(p -> {
                if (p.contains("geometry")) {
                    try {
                        arr.add(MAPPER.readTree(p.getString("geometry")));
                    } catch(Exception ignored) {}
                }
            });
        } catch(Exception e) {
            // ignore invalid id
        }
        return arr;
    }

    /* ============================================================= 
     *                GET /events  (todos os roles)                  
     * ============================================================= */
    @GET
    public Response listAll(@HeaderParam("Authorization") String auth,
                           @QueryParam("lat") Double lat,
                           @QueryParam("lng") Double lng) {
        String token = jwt(auth);
        if (token == null)
            return Response.status(Response.Status.UNAUTHORIZED).build();

        // Buscar todos os eventos
        Query<Entity> q = Query.newEntityQueryBuilder().setKind("Event").build();
        List<Event> events = new ArrayList<>();
        DS.run(q).forEachRemaining(e -> events.add(Event.fromEntity(e)));

        // Ordenar por proximidade se coordenadas fornecidas
        if (lat != null && lng != null) {
            events.sort(Comparator.comparingDouble(ev -> {
                try {
                    String[] parts = ev.location.split(",");
                    double eLat = Double.parseDouble(parts[0]);
                    double eLng = Double.parseDouble(parts[1]);
                    return haversine(lat, lng, eLat, eLng);
                } catch (Exception ex) {
                    return Double.MAX_VALUE; // ignora locais malformados
                }
            }));
        }

        return Response.ok(events).build();
    }

    /* ============================================================= 
     *                GET /events/registered  (RU apenas)                  
     * ============================================================= */
    @GET
    @Path("/registered")
    public Response listMyEvents(@HeaderParam("Authorization") String auth) {
        String token = jwt(auth);
        if (token == null)
            return Response.status(Response.Status.UNAUTHORIZED).build();

        List<String> userRoles = roles(token);
        if (!userRoles.contains("RU")) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Apenas utilizadores RU podem ver os seus eventos registados")
                    .build();
        }

        String user = username(token);
        if (user == null)
            return Response.status(Response.Status.UNAUTHORIZED).build();

        // Buscar registos do utilizador
        Query<Entity> regQuery = Query.newEntityQueryBuilder()
                .setKind("EventReg")
                .setFilter(PropertyFilter.eq("username", user))
                .build();

        List<Event> myEvents = new ArrayList<>();
        DS.run(regQuery).forEachRemaining(reg -> {
            String eventId = reg.getString("eventId");
            Key eventKey = KF_EVENT.newKey(eventId);
            Entity eventEntity = DS.get(eventKey);
            if (eventEntity != null) {
                myEvents.add(Event.fromEntity(eventEntity));
            }
        });

        return Response.ok(myEvents).build();
    }

    /* ============================================================= 
     *                POST /events/{id}/register  (RU apenas)                  
     * ============================================================= */
    @POST
    @Path("/{id}/register")
    public Response registerForEvent(@HeaderParam("Authorization") String auth,
                                   @PathParam("id") String eventId) {
        String token = jwt(auth);
        if (token == null)
            return Response.status(Response.Status.UNAUTHORIZED).build();

        List<String> userRoles = roles(token);
        if (!userRoles.contains("RU")) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Apenas utilizadores RU podem registar-se em eventos")
                    .build();
        }

        String user = username(token);
        if (user == null)
            return Response.status(Response.Status.UNAUTHORIZED).build();

        // Verificar se o evento existe
        Key eventKey = KF_EVENT.newKey(eventId);
        Entity eventEntity = DS.get(eventKey);
        if (eventEntity == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("Evento não encontrado")
                    .build();
        }

        // Verificar se já está registado
        Query<Entity> checkQuery = Query.newEntityQueryBuilder()
                .setKind("EventReg")
                .setFilter(StructuredQuery.CompositeFilter.and(
                        PropertyFilter.eq("eventId", eventId),
                        PropertyFilter.eq("username", user)
                ))
                .build();

        if (DS.run(checkQuery).hasNext()) {
            return Response.status(Response.Status.CONFLICT)
                    .entity("Já está registado neste evento")
                    .build();
        }

        // Criar registo
        String regId = UUID.randomUUID().toString();
        Key regKey = KF_REG.newKey(regId);
        Entity registration = Entity.newBuilder(regKey)
                .set("eventId", eventId)
                .set("username", user)
                .set("registrationDate", com.google.cloud.Timestamp.now())
                .build();

        DS.put(registration);

        return Response.ok()
                .entity("Registado com sucesso no evento")
                .build();
    }

    /* ============================================================= 
     *                DELETE /events/{id}/register  (RU apenas)                  
     * ============================================================= */
    @DELETE
    @Path("/{id}/register")
    public Response unregisterFromEvent(@HeaderParam("Authorization") String auth,
                                      @PathParam("id") String eventId) {
        String token = jwt(auth);
        if (token == null)
            return Response.status(Response.Status.UNAUTHORIZED).build();

        List<String> userRoles = roles(token);
        if (!userRoles.contains("RU")) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Apenas utilizadores RU podem cancelar registo em eventos")
                    .build();
        }

        String user = username(token);
        if (user == null)
            return Response.status(Response.Status.UNAUTHORIZED).build();

        // Verificar se o evento existe
        Key eventKey = KF_EVENT.newKey(eventId);
        Entity eventEntity = DS.get(eventKey);
        if (eventEntity == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("Evento não encontrado")
                    .build();
        }

        // Procurar o registo do utilizador para este evento
        Query<Entity> regQuery = Query.newEntityQueryBuilder()
                .setKind("EventReg")
                .setFilter(StructuredQuery.CompositeFilter.and(
                        PropertyFilter.eq("eventId", eventId),
                        PropertyFilter.eq("username", user)
                ))
                .build();

        QueryResults<Entity> results = DS.run(regQuery);
        if (!results.hasNext()) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("Não está registado neste evento")
                    .build();
        }

        // Apagar o registo
        Entity registration = results.next();
        DS.delete(registration.getKey());

        return Response.ok()
                .entity("Registo cancelado com sucesso")
                .build();
    }

    /* ============================================================= 
     *                GET /events/{id}  (todos os roles)                  
     * ============================================================= */
    @GET
    @Path("/{id}")
    public Response getEvent(@HeaderParam("Authorization") String auth,
                           @PathParam("id") String eventId) {
        String token = jwt(auth);
        if (token == null)
            return Response.status(Response.Status.UNAUTHORIZED).build();

        Key eventKey = KF_EVENT.newKey(eventId);
        Entity eventEntity = DS.get(eventKey);
        if (eventEntity == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("Evento não encontrado")
                    .build();
        }

        Event event = Event.fromEntity(eventEntity);
        return Response.ok(event).build();
    }
}