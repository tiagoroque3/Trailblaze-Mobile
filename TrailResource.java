package pt.unl.fct.di.apdc.trailblaze.resources;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.Response.Status;

import com.google.cloud.datastore.*;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import pt.unl.fct.di.apdc.trailblaze.util.*;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Resource para gestão de trilhos por utilizadores RU
 */
@Path("/trails")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class TrailResource {

    private static final Datastore DS = DatastoreOptions.getDefaultInstance().getService();

    /**
     * Extrai token do header Authorization
     */
    private String extractToken(String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return null;
        }
        return authHeader.substring("Bearer ".length()).trim();
    }

    /**
     * Verifica se o utilizador tem role RU
     */
    private boolean hasRURole(String token) {
        try {
            List<String> roles = JwtUtil.getUserRoles(token);
            return roles != null && roles.contains("RU");
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Verifica se a worksheet existe
     */
    private boolean worksheetExists(String worksheetId) {
        try {
            long id = Long.parseLong(worksheetId);
            Key key = DS.newKeyFactory().setKind("WorkSheet").newKey(id);
            return DS.get(key) != null;
        } catch (NumberFormatException e) {
            return false;
        }
    }

    /**
     * Procura trilho por ID em todas as worksheets
     */
    private Entity findTrailById(String trailId) {
        Query<Entity> query = Query.newEntityQueryBuilder()
                .setKind("Trail")
                .build();

        QueryResults<Entity> results = DS.run(query);
        while (results.hasNext()) {
            Entity entity = results.next();
            if (trailId.equals(entity.getKey().getName())) {
                return entity;
            }
        }
        return null;
    }

    /**
     * Converte Trail para Map para evitar problemas de serialização
     */
    private Map<String, Object> trailToMap(Trail trail) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", trail.id);
        map.put("name", trail.name);
        map.put("createdBy", trail.createdBy);
        map.put("worksheetId", trail.worksheetId);
        map.put("visibility", trail.visibility.name());
        map.put("createdAt", trail.createdAt.getTime());
        map.put("points", trail.points);
        map.put("observations", trail.observations);
        
        if (trail.visibility == TrailVisibility.PRIVATE && trail.status != null) {
            map.put("status", trail.status.name());
        }
        
        return map;
    }

    /**
     * POST /trails/create - Criar novo trilho
     */
    @POST
    @Path("/create")
    public Response createTrail(@HeaderParam("Authorization") String authHeader,
                                CreateTrailRequest request) {

        String token = extractToken(authHeader);
        if (token == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token ausente").build();
        }

        if (!hasRURole(token)) {
            return Response.status(Status.FORBIDDEN)
                    .entity("Apenas utilizadores RU podem criar trilhos").build();
        }

        String username = JwtUtil.getUsername(token);
        if (username == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token inválido").build();
        }

        if (request == null || !request.isValid()) {
            return Response.status(Status.BAD_REQUEST)
                    .entity("Dados do trilho inválidos").build();
        }

        if (!worksheetExists(request.worksheetId)) {
            return Response.status(Status.NOT_FOUND)
                    .entity("Worksheet não encontrada").build();
        }

        try {
            Trail trail = new Trail(request.name, username, request.worksheetId);
            trail.visibility = request.visibility != null ? request.visibility : TrailVisibility.PRIVATE;
            trail.points = request.points != null ? request.points : new ArrayList<>();
            
            // Adicionar proximidades se existirem
            if (request.worksheetProximities != null && !request.worksheetProximities.isEmpty()) {
                trail.worksheetProximities = request.worksheetProximities;
            }

            // Adicionar observação inicial se existir
            if (request.initialObservation != null && !request.initialObservation.trim().isEmpty()) {
                trail.addObservation(username, request.initialObservation);
            }

            boolean nearWS = isTrailNearAnyPolygon(trail.points, 5.0);
            
            DS.put(trail.toEntity(DS));

            // Retornar como Map para evitar problemas de serialização
            Map<String, Object> response = new HashMap<>();
            response.put("trail", trailToMap(trail));
            response.put("nearWorkSheet", nearWS);

            return Response.status(Status.CREATED)
                    .entity(response).build();

        } catch (Exception e) {
            return Response.status(Status.INTERNAL_SERVER_ERROR)
                    .entity("Erro ao criar trilho: " + e.getMessage()).build();
        }
    }

    /**
     * GET /trails/list - Listar todos os trilhos públicos + trilhos próprios do utilizador
     */
    @GET
    @Path("/list")
    public Response listTrails(@HeaderParam("Authorization") String authHeader) {

        String token = extractToken(authHeader);
        if (token == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token ausente").build();
        }

        if (!hasRURole(token)) {
            return Response.status(Status.FORBIDDEN)
                    .entity("Apenas utilizadores RU podem ver trilhos").build();
        }

        String username = JwtUtil.getUsername(token);
        if (username == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token inválido").build();
        }

        try {
            List<Map<String, Object>> trails = new ArrayList<>();

            // Query para todos os trilhos
            Query<Entity> query = Query.newEntityQueryBuilder()
                    .setKind("Trail")
                    .build();

            QueryResults<Entity> results = DS.run(query);

            while (results.hasNext()) {
                Entity entity = results.next();
                Trail trail = Trail.fromEntity(entity);

                // Incluir se:
                // 1. É trilho público (qualquer utilizador pode ver)
                // 2. É trilho do próprio utilizador (independente da visibilidade)
                if (trail.visibility == TrailVisibility.PUBLIC || trail.createdBy.equals(username)) {
                    trails.add(trailToMap(trail));
                }
            }

            return Response.ok(trails).build();

        } catch (Exception e) {
            return Response.status(Status.INTERNAL_SERVER_ERROR)
                    .entity("Erro ao listar trilhos: " + e.getMessage()).build();
        }
    }

    /**
     * GET /trails/get/{id} - Obter trilho específico
     */
    @GET
    @Path("/get/{id}")
    public Response getTrail(@HeaderParam("Authorization") String authHeader,
                             @PathParam("id") String trailId) {

        String token = extractToken(authHeader);
        if (token == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token ausente").build();
        }

        if (!hasRURole(token)) {
            return Response.status(Status.FORBIDDEN)
                    .entity("Apenas utilizadores RU podem ver trilhos").build();
        }

        String username = JwtUtil.getUsername(token);
        if (username == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token inválido").build();
        }

        try {
            Entity entity = findTrailById(trailId);

            if (entity == null) {
                return Response.status(Status.NOT_FOUND)
                        .entity("Trilho não encontrado").build();
            }

            Trail trail = Trail.fromEntity(entity);

            if (!trail.canBeViewedBy(username)) {
                return Response.status(Status.FORBIDDEN)
                        .entity("Sem permissão para ver este trilho").build();
            }

            return Response.ok(trailToMap(trail)).build();

        } catch (Exception e) {
            return Response.status(Status.INTERNAL_SERVER_ERROR)
                    .entity("Erro ao obter trilho: " + e.getMessage()).build();
        }
    }

    /**
     * PUT /trails/update/{id} - Adicionar observação ao trilho
     */
    @PUT
    @Path("/update/{id}")
    public Response updateTrail(@HeaderParam("Authorization") String authHeader,
                                @PathParam("id") String trailId,
                                UpdateTrailRequest request) {

        String token = extractToken(authHeader);
        if (token == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token ausente").build();
        }

        if (!hasRURole(token)) {
            return Response.status(Status.FORBIDDEN)
                    .entity("Apenas utilizadores RU podem editar trilhos").build();
        }

        String username = JwtUtil.getUsername(token);
        if (username == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token inválido").build();
        }

        if (request == null || !request.hasValidObservation()) {
            return Response.status(Status.BAD_REQUEST)
                    .entity("Observação inválida ou em falta").build();
        }

        try {
            Entity entity = findTrailById(trailId);

            if (entity == null) {
                return Response.status(Status.NOT_FOUND)
                        .entity("Trilho não encontrado").build();
            }

            Trail trail = Trail.fromEntity(entity);

            if (!trail.canBeEditedBy(username)) {
                return Response.status(Status.FORBIDDEN)
                        .entity("Sem permissão para editar este trilho").build();
            }

            // Adicionar nova observação
            trail.addObservation(username, request.observation);

            DS.put(trail.toEntity(DS));

            return Response.ok(trailToMap(trail)).build();

        } catch (Exception e) {
            return Response.status(Status.INTERNAL_SERVER_ERROR)
                    .entity("Erro ao atualizar trilho: " + e.getMessage()).build();
        }
    }

    /**
     * PUT /trails/{id}/visibility - Alterar visibilidade do trilho (apenas criador)
     */
    @PUT
    @Path("/{id}/visibility")
    public Response updateTrailVisibility(@HeaderParam("Authorization") String authHeader,
                                          @PathParam("id") String trailId,
                                          UpdateTrailVisibilityRequest request) {

        String token = extractToken(authHeader);
        if (token == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token ausente").build();
        }

        if (!hasRURole(token)) {
            return Response.status(Status.FORBIDDEN)
                    .entity("Apenas utilizadores RU podem editar trilhos").build();
        }

        String username = JwtUtil.getUsername(token);
        if (username == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token inválido").build();
        }

        if (request == null || request.visibility == null) {
            return Response.status(Status.BAD_REQUEST)
                    .entity("Visibilidade inválida").build();
        }

        try {
            Entity entity = findTrailById(trailId);

            if (entity == null) {
                return Response.status(Status.NOT_FOUND)
                        .entity("Trilho não encontrado").build();
            }

            Trail trail = Trail.fromEntity(entity);

            if (!trail.createdBy.equals(username)) {
                return Response.status(Status.FORBIDDEN)
                        .entity("Apenas o criador pode alterar a visibilidade do trilho").build();
            }

            // Alterar visibilidade
            trail.visibility = request.visibility;

            // Se mudou para público, remover status
            // Se mudou para privado e não tinha status, definir como ACTIVE
            if (trail.visibility == TrailVisibility.PRIVATE && trail.status == null) {
                trail.status = TrailStatus.ACTIVE;
            }

            DS.put(trail.toEntity(DS));

            return Response.ok(trailToMap(trail)).build();

        } catch (Exception e) {
            return Response.status(Status.INTERNAL_SERVER_ERROR)
                    .entity("Erro ao alterar visibilidade do trilho: " + e.getMessage()).build();
        }
    }

    /**
     * PUT /trails/{id}/status - Atualizar status do trilho (apenas para trilhos privados)
     */
    @PUT
    @Path("/{id}/status")
    public Response updateTrailStatus(@HeaderParam("Authorization") String authHeader,
                                      @PathParam("id") String trailId,
                                      UpdateTrailStatusRequest request) {

        String token = extractToken(authHeader);
        if (token == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token ausente").build();
        }

        if (!hasRURole(token)) {
            return Response.status(Status.FORBIDDEN)
                    .entity("Apenas utilizadores RU podem editar trilhos").build();
        }

        String username = JwtUtil.getUsername(token);
        if (username == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token inválido").build();
        }

        if (request == null || request.status == null) {
            return Response.status(Status.BAD_REQUEST)
                    .entity("Status inválido").build();
        }

        try {
            Entity entity = findTrailById(trailId);

            if (entity == null) {
                return Response.status(Status.NOT_FOUND)
                        .entity("Trilho não encontrado").build();
            }

            Trail trail = Trail.fromEntity(entity);

            if (!trail.createdBy.equals(username)) {
                return Response.status(Status.FORBIDDEN)
                        .entity("Apenas o criador pode alterar o status do trilho").build();
            }

            if (trail.visibility == TrailVisibility.PUBLIC) {
                return Response.status(Status.BAD_REQUEST)
                        .entity("Trilhos públicos não têm status").build();
            }

            // Atualizar status
            trail.status = request.status;

            DS.put(trail.toEntity(DS));

            return Response.ok(trailToMap(trail)).build();

        } catch (Exception e) {
            return Response.status(Status.INTERNAL_SERVER_ERROR)
                    .entity("Erro ao atualizar status do trilho: " + e.getMessage()).build();
        }
    }

    /**
     * DELETE /trails/delete/{id} - Apagar trilho
     */
    @DELETE
    @Path("/delete/{id}")
    public Response deleteTrail(@HeaderParam("Authorization") String authHeader,
                                @PathParam("id") String trailId) {

        String token = extractToken(authHeader);
        if (token == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token ausente").build();
        }

        if (!hasRURole(token)) {
            return Response.status(Status.FORBIDDEN)
                    .entity("Apenas utilizadores RU podem apagar trilhos").build();
        }

        String username = JwtUtil.getUsername(token);
        if (username == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token inválido").build();
        }

        try {
            Entity entity = findTrailById(trailId);

            if (entity == null) {
                return Response.status(Status.NOT_FOUND)
                        .entity("Trilho não encontrado").build();
            }

            Trail trail = Trail.fromEntity(entity);

            if (!trail.createdBy.equals(username)) {
                return Response.status(Status.FORBIDDEN)
                        .entity("Apenas o criador pode apagar este trilho").build();
            }

            DS.delete(entity.getKey());

            return Response.ok()
                    .entity("Trilho apagado com sucesso")
                    .build();

        } catch (Exception e) {
            return Response.status(Status.INTERNAL_SERVER_ERROR)
                    .entity("Erro ao apagar trilho: " + e.getMessage()).build();
        }
    }

    /**
     * GET /trails/worksheet/{worksheetId} - Listar trilhos de uma worksheet específica
     */
    @GET
    @Path("/worksheet/{worksheetId}")
    public Response getTrailsByWorksheet(@HeaderParam("Authorization") String authHeader,
                                         @PathParam("worksheetId") String worksheetId) {

        String token = extractToken(authHeader);
        if (token == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token ausente").build();
        }

        if (!hasRURole(token)) {
            return Response.status(Status.FORBIDDEN)
                    .entity("Apenas utilizadores RU podem ver trilhos").build();
        }

        String username = JwtUtil.getUsername(token);
        if (username == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token inválido").build();
        }

        if (!worksheetExists(worksheetId)) {
            return Response.status(Status.NOT_FOUND)
                    .entity("Worksheet não encontrada").build();
        }

        try {
            List<Map<String, Object>> trails = new ArrayList<>();

            // Query simples para trilhos da worksheet específica
            Query<Entity> query = Query.newEntityQueryBuilder()
                    .setKind("Trail")
                    .setFilter(StructuredQuery.PropertyFilter.eq("worksheetId", worksheetId))
                    .build();

            QueryResults<Entity> results = DS.run(query);

            while (results.hasNext()) {
                Entity entity = results.next();
                Trail trail = Trail.fromEntity(entity);

                // Filtro no backend: próprios trilhos OU trilhos públicos
                if (trail.canBeViewedBy(username)) {
                    trails.add(trailToMap(trail));
                }
            }

            return Response.ok(trails).build();

        } catch (Exception e) {
            return Response.status(Status.INTERNAL_SERVER_ERROR)
                    .entity("Erro ao listar trilhos da worksheet: " + e.getMessage()).build();
        }
    }
    
    
    /* ----------------------------------------------------------- */
    /*                    Helper functions                        */
    /* ----------------------------------------------------------- */

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private static double toRadians(double deg) {
        return deg * Math.PI / 180.0;
    }

    /** Distância aproximada (km) usando fórmula de Haversine. */
    private static double haversine(double lat1, double lon1, double lat2, double lon2) {
        final double R = 6371.0;
        double dLat = toRadians(lat2 - lat1);
        double dLon = toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2))
                + Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private static void collectCoords(JsonNode node, List<double[]> out) {
        if (node == null || !node.isArray()) return;

        if (node.size() == 2 && node.get(0).isNumber() && node.get(1).isNumber()) {
            out.add(new double[]{ node.get(0).asDouble(), node.get(1).asDouble() });
        } else {
            for (JsonNode child : node) {
                collectCoords(child, out);
            }
        }
    }

    private boolean isTrailNearAnyPolygon(List<TrailPoint> points, double maxKm) {
        if (points == null || points.isEmpty()) {
            return false;
        }
        
        Query<Entity> q = Query.newEntityQueryBuilder().setKind("Parcel").build();
        QueryResults<Entity> results = DS.run(q);

        while (results.hasNext()) {
            Entity parcel = results.next();
            if (!parcel.contains("geometry")) continue;

            try {
                JsonNode geo = MAPPER.readTree(parcel.getString("geometry"));
                List<double[]> coords = new ArrayList<>();
                collectCoords(geo.path("coordinates"), coords);

                for (TrailPoint tp : points) {
                    for (double[] c : coords) {
                        double dist = haversine(tp.latitude, tp.longitude, c[1], c[0]);
                        if (dist <= maxKm) return true;
                    }
                }
            } catch (Exception ignored) {
            }
        }
        return false;
    }
}