package pt.unl.fct.di.apdc.trailblaze.resources;

import java.util.List;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.google.cloud.datastore.Datastore;
import com.google.cloud.datastore.DatastoreOptions;
import com.google.cloud.datastore.Entity;
import com.google.cloud.datastore.EntityQuery;
import com.google.cloud.datastore.Key;
import com.google.cloud.datastore.Query;
import com.google.cloud.datastore.StructuredQuery;
import com.google.cloud.datastore.KeyFactory;
import com.google.cloud.datastore.PathElement;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import pt.unl.fct.di.apdc.trailblaze.util.JwtUtil;
import pt.unl.fct.di.apdc.trailblaze.util.WorkSheetUtil;

@Path("/fo")
@Produces(MediaType.APPLICATION_JSON)
public class WorkSheetViewResource {

    private static final Datastore DS = DatastoreOptions.getDefaultInstance().getService();
    private static final ObjectMapper MAPPER = new ObjectMapper();

    /* =============================================================== *
     *                    GET /fo/{id}/generic                         *
     * =============================================================== */
    @GET
    @Path("/{id}/generic")
    public Response viewGeneric(@PathParam("id") long id) {
        Entity ws = DS.get(DS.newKeyFactory().setKind("WorkSheet").newKey(id));
        if (ws == null) return Response.status(Response.Status.NOT_FOUND).build();

        ObjectNode json = WorkSheetUtil.toGenericJson(ws);
        return Response.ok(json.toString()).build();
    }

    /* =============================================================== *
     *                    GET /fo/{id}/detail                          *
     *    • SMBO e SDVBO (conta ATIVADA)                               *
     * =============================================================== */
    @GET
    @Path("/{id}/detail")
    public Response viewDetail(@HeaderParam("Authorization") String hdr,
                               @PathParam("id") long id) {
        /* ---------- 1) autenticação opcional ---------- */
        List<String> roles = List.of();   // vazio = utilizador anónimo
        if (hdr != null && !hdr.isBlank()) {
            String jwt = token(hdr);
            try { roles = rolesFromToken(jwt); }
            catch (Exception e) { return Response.status(Response.Status.UNAUTHORIZED).build(); }
            if (roles.stream().noneMatch(r -> r.equals("SMBO") || r.equals("SDVBO") || r.equals("SGVBO") || r.equals("RU") || r.equals("ADLU")|| r.equals("PO") ||r.equals("PRBO") || r.equals("SYSADMIN") || r.equals("SYSBO") ))
                return Response.status(Response.Status.FORBIDDEN).build();
        }

        /* ---------- 2) obter worksheet ---------- */
        Key wsKey = DS.newKeyFactory().setKind("WorkSheet").newKey(id);
        Entity ws = DS.get(wsKey);
        if (ws == null) return Response.status(Response.Status.NOT_FOUND).build();

        /* ---------- 3) operações + parcelas ---------- */
        Query<Entity> qOps = Query.newEntityQueryBuilder()
                .setKind("Operation")
                .setFilter(StructuredQuery.PropertyFilter.hasAncestor(wsKey))
                .setOrderBy(StructuredQuery.OrderBy.asc("order"))
                .build();

        Query<Entity> qParcels = Query.newEntityQueryBuilder()
                .setKind("Parcel")
                .setFilter(StructuredQuery.PropertyFilter.hasAncestor(wsKey))
                .build();

        ObjectNode detail = WorkSheetUtil.toDetailJson(ws, DS.run(qOps), DS.run(qParcels));
        return Response.ok(detail.toString()).build();
    }

    /* =============================================================== *
     *                    GET /fo/{id}/parcels                         *
     *    • Returns all parcels for a specific worksheet               *
     * =============================================================== */
    @GET
    @Path("/{id}/parcels")
    public Response getParcels(@HeaderParam("Authorization") String hdr,
                               @PathParam("id") long id) {
        /* ---------- 1) authentication ---------- */
        if (hdr == null || hdr.isBlank()) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        }
        
        String jwt = token(hdr);
        List<String> roles;
        try {
            roles = rolesFromToken(jwt);
        } catch (Exception e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        }
        
        if (roles.stream().noneMatch(r -> r.equals("SMBO") || r.equals("SDVBO") || r.equals("SGVBO") || 
                                         r.equals("RU") || r.equals("ADLU") || r.equals("PO") || 
                                         r.equals("PRBO") || r.equals("SYSADMIN") || r.equals("SYSBO"))) {
            return Response.status(Response.Status.FORBIDDEN).build();
        }

        /* ---------- 2) check if worksheet exists ---------- */
        Key wsKey = DS.newKeyFactory().setKind("WorkSheet").newKey(id);
        Entity ws = DS.get(wsKey);
        if (ws == null) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }

        /* ---------- 3) get all parcels for this worksheet ---------- */
        Query<Entity> qParcels = Query.newEntityQueryBuilder()
                .setKind("Parcel")
                .setFilter(StructuredQuery.PropertyFilter.hasAncestor(wsKey))
                .build();

        ArrayNode parcelsArray = MAPPER.createArrayNode();
        DS.run(qParcels).forEachRemaining(parcel -> {
            ObjectNode parcelJson = MAPPER.createObjectNode();
            
            // Get parcel ID (can be from key name or id property)
            String parcelId = parcel.getKey().getName();
            if (parcelId == null) {
                parcelId = String.valueOf(parcel.getKey().getId());
            }
            
            parcelJson.put("id", parcelId);
            parcelJson.put("parcelId", parcelId);
            
            // Add other parcel properties - handle different types
            if (parcel.contains("aigp")) {
                Object aigp = parcel.getValue("aigp").get();
                parcelJson.put("aigp", aigp.toString());
            }
            if (parcel.contains("ruralPropertyId")) {
                Object ruralPropertyId = parcel.getValue("ruralPropertyId").get();
                parcelJson.put("ruralPropertyId", ruralPropertyId.toString());
            }
            if (parcel.contains("polygonId")) {
                Object polygonId = parcel.getValue("polygonId").get();
                parcelJson.put("polygonId", polygonId.toString());
            }
            if (parcel.contains("geometry")) {
                Object geometry = parcel.getValue("geometry").get();
                parcelJson.put("geometry", geometry.toString());
            }
            
            parcelsArray.add(parcelJson);
        });

        return Response.ok(parcelsArray.toString()).build();
    }

    /* =============================================================== *
     *              GET /fo/search/generic    (público)                *
     * =============================================================== */
    @GET
    @Path("/search/generic")
    public Response searchGeneric(@QueryParam("serviceProviderId") Long spId,
                                  @QueryParam("posaCode") String posaCode) {
        try {
            EntityQuery.Builder qb = Query.newEntityQueryBuilder().setKind("WorkSheet");
            if (spId != null)
                qb.setFilter(StructuredQuery.PropertyFilter.eq("serviceProviderId", spId));
            else if (posaCode != null && !posaCode.isBlank())
                qb.setFilter(StructuredQuery.PropertyFilter.eq("posaCode", posaCode));

            ArrayNode arr = MAPPER.createArrayNode();
            DS.run(qb.build()).forEachRemaining(ws -> arr.add(WorkSheetUtil.toGenericJson(ws)));

            return Response.ok(arr.toString()).build();
        } catch (Exception ex) {
            ex.printStackTrace();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                           .entity("Erro interno: " + ex.getMessage()).build();
        }
    }

    /* ---------------- utils ---------------- */
    private static String token(String hdr) {
        return hdr.replaceFirst("(?i)^Bearer\\s+", "").trim();
    }

    /** Extrai a lista completa de roles do JWT (compatível com tokens antigos). */
    @SuppressWarnings("unchecked")
    private static List<String> rolesFromToken(String jwt) {
        var claims = JwtUtil.validateToken(jwt).getBody();
        return claims.containsKey("roles")
               ? claims.get("roles", List.class)
               : List.of(claims.get("role", String.class));
    }

    /* =============================================================== *
    *                   GET /fo/{id}/parcels/{parcelId}  
    *           • Returns a single parcel with GeoJSON geometry              *
    * =============================================================== */
    @GET
    @Path("/{id}/parcels/{parcelId}")
    @Produces(MediaType.APPLICATION_JSON)
    public Response getParcelById(@HeaderParam("Authorization") String hdr,
                          @PathParam("id") long worksheetId,
                          @PathParam("parcelId") String parcelId) {
    /* ---------- 1) Authentication & Authorization ---------- */
    if (hdr == null || hdr.isBlank()) {
        return Response.status(Response.Status.UNAUTHORIZED).build();
    }
    String jwt = token(hdr);
    try {
        List<String> roles = rolesFromToken(jwt);
        if (roles.stream().noneMatch(r -> r.equals("PO") || r.equals("SMBO") || r.equals("SYSADMIN"))) {
            return Response.status(Response.Status.FORBIDDEN).build();
        }
    } catch (Exception e) {
        return Response.status(Response.Status.UNAUTHORIZED).build();
    }

    /* ---------- 2) Get Parcel ---------- */
    Key parcelKey;
    // CORRECTED: Create a KeyFactory for the "Parcel" kind and add the WorkSheet ancestor.
    KeyFactory keyFactory = DS.newKeyFactory()
                            .addAncestor(PathElement.of("WorkSheet", worksheetId))
                            .setKind("Parcel");

    // The parcelId from the path can be a numeric ID or a string name.
    try {
        long numericId = Long.parseLong(parcelId);
        parcelKey = keyFactory.newKey(numericId);
    } catch (NumberFormatException e) {
        parcelKey = keyFactory.newKey(parcelId);
    }

    Entity parcel = DS.get(parcelKey);

    if (parcel == null) {
        return Response.status(Response.Status.NOT_FOUND).entity("Parcel with ID " + parcelId + " not found.").build();
    }

    /* ---------- 3) Build JSON Response ---------- */
    ObjectNode parcelJson = MAPPER.createObjectNode();
    String id = parcel.getKey().getName() != null ? parcel.getKey().getName() : String.valueOf(parcel.getKey().getId());
    parcelJson.put("id", id);
    parcelJson.put("parcelId", id);

    if (parcel.contains("aigp")) parcelJson.put("aigp", parcel.getString("aigp"));
    if (parcel.contains("ruralPropertyId")) parcelJson.put("ruralPropertyId", parcel.getString("ruralPropertyId"));
    if (parcel.contains("polygonId")) {
        long fetchedPolygonId = parcel.getLong("polygonId");
        parcelJson.put("polygonId", String.valueOf(fetchedPolygonId));
        }

    // Correctly parse and add geometry as a JSON object
    if (parcel.contains("geometry")) {
        String geometryStr = parcel.getString("geometry");
        try {
            JsonNode geometryJson = MAPPER.readTree(geometryStr);
            parcelJson.set("geometry", geometryJson);
        } catch (Exception e) {
            System.err.println("Could not parse geometry for parcel " + id + ": " + e.getMessage());
            parcelJson.putNull("geometry");
        }
    }

    return Response.ok(parcelJson.toString()).build();
}
    
}
