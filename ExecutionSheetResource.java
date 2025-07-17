package pt.unl.fct.di.apdc.trailblaze.resources;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

import jakarta.json.Json;
import jakarta.json.JsonArrayBuilder;
import jakarta.json.JsonObjectBuilder;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.Response.Status;

import com.google.cloud.Timestamp;
import com.google.cloud.datastore.*;

import io.jsonwebtoken.JwtException;
import pt.unl.fct.di.apdc.trailblaze.util.*;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import java.util.*;
import com.google.cloud.datastore.*;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.*;

import com.google.cloud.datastore.StructuredQuery.PropertyFilter;


@Path("/fe")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ExecutionSheetResource {

    private static final ObjectMapper mapper = new ObjectMapper();

    private static final Datastore datastore =
            DatastoreOptions.getDefaultInstance().getService();
    private static final KeyFactory esKeyFactory =
            datastore.newKeyFactory().setKind("ExecutionSheet");
    private static final KeyFactory opExecKeyFactory =
            datastore.newKeyFactory().setKind("OperationExecution");
    private static final KeyFactory workSheetKeyFactory =
            datastore.newKeyFactory().setKind("WorkSheet");

    /* -----------------  ----------------- */

    /**
     * Extrai o token JWT de um header Authorization.
     */
    private static String extractToken(String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) return null;
        return authHeader.substring("Bearer ".length()).trim();
    }

    /**
     * GET /fe - Lista todas as folhas de execução (com controlo de permissões)
     */
    @GET
    public Response listExecutionSheets(@HeaderParam("Authorization") String auth,
                                        @QueryParam("status") String statusFilter) {
        // 1. Validar token
        String token = extractToken(auth);
        if (token == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("Token ausente ou inválido").build();
        }

        try {
            JwtUtil.validateToken(token);
        } catch (JwtException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("Token inválido ou expirado").build();
        }

        // 2. Obter utilizador e roles
        String username = JwtUtil.getUsername(token);
        List<String> userRoles = JwtUtil.getUserRoles(token);

        if (username == null || userRoles == null || userRoles.isEmpty()) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("Utilizador inválido").build();
        }

        // 3. Determinar tipo de acesso
        boolean acessoGlobal = false;
        boolean acessoRestrito = false;

        for (String role : userRoles) {
            switch (role) {
                case "SYSADMIN":
                case "SYSBO":
                case "SDVBO":
                case "SMBO":
                    acessoGlobal = true;
                    break;
                case "PRBO":
                case "PO":
                    acessoRestrito = true;
                    break;
                case "RU":
                case "ADLU":
                case "VU":
                case "SGVBO":
                    // Estes não têm acesso
                    // Não marcamos nada
                    break;
            }
        }

        // Se não tiver acesso global nem restrito, proibir
        if (!acessoGlobal && !acessoRestrito) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Sem permissões para visualizar folhas de execução").build();
        }

        // 4. Construir query
        EntityQuery.Builder queryBuilder = Query.newEntityQueryBuilder()
                .setKind("ExecutionSheet");

        if (statusFilter != null && !statusFilter.isEmpty()) {
            // Filtro por estado
            if (acessoRestrito && !acessoGlobal) {
                // Restringir por utilizador também
                queryBuilder.setFilter(StructuredQuery.CompositeFilter.and(
                        PropertyFilter.eq("associatedUser", username),
                        PropertyFilter.eq("state", statusFilter)
                ));
            } else {
                // Global apenas por estado
                queryBuilder.setFilter(PropertyFilter.eq("state", statusFilter));
            }
        } else {
            // Sem filtro de estado
            if (acessoRestrito && !acessoGlobal) {
                queryBuilder.setFilter(PropertyFilter.eq("associatedUser", username));
            }
            // Se for acesso global, não aplica filtros adicionais
        }

        Query<Entity> query = queryBuilder.build();

        // 5. Executar query
        QueryResults<Entity> results = datastore.run(query);
        List<Map<String, Object>> sheets = new ArrayList<>();

        while (results.hasNext()) {
            Entity entity = results.next();
            ExecutionSheet sheet = ExecutionSheet.fromEntity(entity);

            Map<String, Object> sheetMap = new HashMap<>();
            sheetMap.put("id", sheet.id);
            sheetMap.put("title", sheet.title);
            sheetMap.put("description", sheet.description);
            sheetMap.put("associatedUser", sheet.associatedUser);
            sheetMap.put("associatedWorkSheetId", sheet.associatedWorkSheetId);
            sheetMap.put("state", sheet.state != null ? sheet.state.name() : null);
            sheetMap.put("startDate", sheet.startDate != null ? sheet.startDate.getTime() : null);
            sheetMap.put("lastActivityDate", sheet.lastActivityDate != null ? sheet.lastActivityDate.getTime() : null);
            sheetMap.put("completionDate", sheet.completionDate != null ? sheet.completionDate.getTime() : null);
            sheetMap.put("observations", sheet.observations);

            sheets.add(sheetMap);
        }

        return Response.ok(sheets).build();
    }


    /**
     * GET /fe/status/{status} - Lista folhas por estado
     */
    @GET
    @Path("/status/{status}")
    public Response listByStatus(@HeaderParam("Authorization") String auth,
                                 @PathParam("status") String status) {
        return listExecutionSheets(auth, status);
    }

    /**
     * GET /fe/user/{username} - Lista folhas de um utilizador específico (admin only)
     */
    @GET
    @Path("/user/{targetUsername}")
    public Response listByUser(@HeaderParam("Authorization") String auth,
                               @PathParam("targetUsername") String targetUsername) {
        String token = extractToken(auth);
        if (token == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("Token ausente").build();
        }

        try {
            JwtUtil.validateToken(token);
        } catch (JwtException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("Token inválido").build();
        }

        List<String> userRoles = JwtUtil.getUserRoles(token);

        // Apenas admins podem ver folhas de outros utilizadores
        if (!userRoles.contains("SYSADMIN") && !userRoles.contains("SYSBO") && !userRoles.contains("SDVBO")) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Sem permissões").build();
        }

        Query<Entity> query = Query.newEntityQueryBuilder()
                .setKind("ExecutionSheet")
                .setFilter(PropertyFilter.eq("associatedUser", targetUsername))
                .build();

        QueryResults<Entity> results = datastore.run(query);
        List<ExecutionSheet> sheets = new ArrayList<>();

        while (results.hasNext()) {
            sheets.add(ExecutionSheet.fromEntity(results.next()));
        }

        return Response.ok(sheets).build();
    }

    @POST
    @Path("/create")
    @Produces(MediaType.APPLICATION_JSON)
    @Consumes(MediaType.APPLICATION_JSON)
    public Response create(@HeaderParam("Authorization") String auth, CreateExecutionSheetRequest req) {
        if (auth == null || !auth.startsWith("Bearer ")) {
            return Response.status(Response.Status.UNAUTHORIZED).entity("Token ausente ou inválido").build();
        }

        String token = auth.substring("Bearer ".length());

        // 1. Validar token
        try {
            JwtUtil.validateToken(token);
        } catch (JwtException e) {
            return Response.status(Response.Status.UNAUTHORIZED).entity("Token inválido ou expirado").build();
        }

        // 2. Verificar role
        if (!JwtUtil.userHasRole(auth, "PRBO")) {
            return Response.status(Response.Status.FORBIDDEN).entity("Acesso negado").build();
        }


        // 3. Obter utilizador
        String username = JwtUtil.getUsername(auth);
        if (username == null) {
            return Response.status(Response.Status.UNAUTHORIZED).entity("Utilizador inválido").build();
        }

        // 4. Validar request
        if (req == null || !req.isValid()) {
            return Response.status(Response.Status.BAD_REQUEST).entity("Dados inválidos").build();
        }

        // 5. Validar existência da folha de obra associada
        if (!ExecutionSheetUtil.workSheetExists(req.associatedWorkSheetId)) {
            return Response.status(Response.Status.NOT_FOUND).entity("Folha de obra não encontrada").build();
        }

        // 6. Criar ExecutionSheet
        ExecutionSheet execSheet = new ExecutionSheet(req.title, req.description, username, req.associatedWorkSheetId);
        Entity execSheetEntity = execSheet.toEntity(datastore);

        // 7. Criar OperationExecution com base nas operações da WorkSheet

        Key worksheetKey = datastore.newKeyFactory().setKind("WorkSheet")
                .newKey(Long.parseLong(req.associatedWorkSheetId));

        Query<Entity> query = Query.newEntityQueryBuilder()
                .setKind("Operation")
                .setFilter(StructuredQuery.PropertyFilter.hasAncestor(worksheetKey))
                .build();

        QueryResults<Entity> operations = datastore.run(query);
        List<Entity> opsToSave = new ArrayList<>();

        while (operations.hasNext()) {
            Entity op = operations.next();
            String opId = op.getKey().getName();
            double area = op.contains("areaHa") ? op.getDouble("areaHa") : 0;

            OperationExecution opExec = new OperationExecution(execSheet.id, opId, area);
            execSheet.operationExecutionIds.add(opExec.id);

            opsToSave.add(opExec.toEntity(datastore)); // toEntity já devolve Entity diretamente
        }

        // 8. Guardar tudo
        List<Entity> entities = new ArrayList<>();
        entities.add(execSheetEntity);  // já é Entity

        entities.addAll(opsToSave);  // todos são Entity

        datastore.put(entities.toArray(new Entity[0]));


        return Response.status(Response.Status.CREATED).entity(execSheet).build();
    }




    @GET
    @Path("/{id}")
    @Produces(MediaType.APPLICATION_JSON)
    public Response get(@HeaderParam("Authorization") String auth,
                        @PathParam("id") String id) {
        // 1) Extrair e validar token
        String token = extractToken(auth);
        if (token == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token ausente ou inválido")
                    .build();
        }

        try {
            JwtUtil.validateToken(token);
        } catch (JwtException ex) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token inválido ou expirado")
                    .build();
        }

        // 2) Obter utilizador
        String user = JwtUtil.getUsername(token);
        if (user == null) {
            return Response.status(Status.UNAUTHORIZED).build();
        }

        // 3) Buscar ExecutionSheet
        Key sheetKey = datastore.newKeyFactory()
                .setKind("ExecutionSheet")
                .newKey(id);
        Entity sheetEntity = datastore.get(sheetKey);
        if (sheetEntity == null) {
            return Response.status(Status.NOT_FOUND)
                    .entity("Folha de execução não encontrada")
                    .build();
        }
        ExecutionSheet sheet = ExecutionSheet.fromEntity(sheetEntity);

        // 4) Autorização
        boolean isOwner = sheet.associatedUser.equals(user);
        List<String> allowedRoles = Arrays.asList("PRBO", "SDVBO", "SGVBO");
        boolean hasAccess = allowedRoles.stream().anyMatch(role -> JwtUtil.userHasRole(token, role));

        if (!isOwner && !hasAccess) {
            return Response.status(Status.FORBIDDEN)
                    .entity("Sem permissões para visualizar esta folha")
                    .build();
        }

        // 5) Carregar OperationExecutions
        Query<Entity> opQuery = Query.newEntityQueryBuilder()
                .setKind("OperationExecution")
                .setFilter(StructuredQuery.PropertyFilter.eq("executionSheetId", sheet.id))
                .build();
        QueryResults<Entity> opResults = datastore.run(opQuery);

        List<Map<String, Object>> operations = new ArrayList<>();

        while (opResults.hasNext()) {
            Entity opEnt = opResults.next();
            OperationExecution opExec = OperationExecution.fromEntity(opEnt);

            // 6) Carregar ParcelOperationExecutions
            Query<Entity> parcelQuery = Query.newEntityQueryBuilder()
                    .setKind("ParcelOperationExecution")
                    .setFilter(StructuredQuery.PropertyFilter.eq("operationExecutionId", opExec.id))
                    .build();
            QueryResults<Entity> parcelResults = datastore.run(parcelQuery);

            List<Map<String, Object>> parcels = new ArrayList<>();

            while (parcelResults.hasNext()) {
                Entity parcelEnt = parcelResults.next();
                ParcelOperationExecution parcel = ParcelOperationExecution.fromEntity(parcelEnt);

                // 7) Carregar Activities
                Query<Entity> actQuery = Query.newEntityQueryBuilder()
                        .setKind("Activity")
                        .setFilter(StructuredQuery.PropertyFilter.eq("parcelOperationExecutionId", parcel.id))
                        .build();
                QueryResults<Entity> actResults = datastore.run(actQuery);

                List<Activity> activities = new ArrayList<>();
                while (actResults.hasNext()) {
                    activities.add(Activity.fromEntity(actResults.next()));
                }

                // 8) Montar parcela
                Map<String, Object> parcelBlock = new HashMap<>();
                parcelBlock.put("parcelExecution", parcel);
                parcelBlock.put("activities", activities);
                parcels.add(parcelBlock);
            }

            // 9) Montar operação
            Map<String, Object> opBlock = new HashMap<>();
            opBlock.put("operationExecution", opExec);
            opBlock.put("parcels", parcels);
            operations.add(opBlock);
        }

        // 10) Construir resposta final
        Map<String, Object> resp = new HashMap<>();
        resp.put("executionSheet", sheet);
        resp.put("operations", operations);

        return Response.ok(resp).build();
    }


    @PUT
    @Path("/{id}")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response update(
            @HeaderParam("Authorization") String auth,
            @PathParam("id") String id,
            UpdateExecutionSheetRequest req
    ) {
        // 1) Autenticação
        String token = extractToken(auth);
        if (token == null) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token ausente ou inválido")
                    .build();
        }

        try {
            JwtUtil.validateToken(token);
        } catch (JwtException e) {
            return Response.status(Status.UNAUTHORIZED)
                    .entity("Token inválido ou expirado")
                    .build();
        }

        // 2) Verificação de utilizador
        String user = JwtUtil.getUsername(token);
        if (user == null) {
            return Response.status(Status.UNAUTHORIZED).build();
        }

        // 3) Verificação de permissões (apenas PRBO e SDVBO)
        List<String> allowedRoles = Arrays.asList("PRBO", "SDVBO");
        boolean hasPermission = allowedRoles.stream().anyMatch(role -> JwtUtil.userHasRole(token, role));

        if (!hasPermission) {
            return Response.status(Status.FORBIDDEN)
                    .entity("Sem permissões para editar esta folha")
                    .build();
        }

        // 4) Obter folha de execução
        Key sheetKey = datastore.newKeyFactory()
                .setKind("ExecutionSheet")
                .newKey(id);
        Entity sheetEntity = datastore.get(sheetKey);
        if (sheetEntity == null) {
            return Response.status(Status.NOT_FOUND)
                    .entity("Folha de execução não encontrada")
                    .build();
        }

        ExecutionSheet sheet = ExecutionSheet.fromEntity(sheetEntity);

        // 5) Atualizações permitidas
        boolean updated = false;

        if (req.title != null) {
            sheet.title = req.title;
            updated = true;
        }
        if (req.description != null) {
            sheet.description = req.description;
            updated = true;
        }
        if (req.observations != null) {
            sheet.observations = req.observations;
            updated = true;
        }
        if (req.state != null) {
            sheet.state = req.state;
            updated = true;
        }
        if (req.startDate != null) {
            sheet.startDate = req.startDate;
            updated = true;
        }
        if (req.lastActivityDate != null) {
            sheet.lastActivityDate = req.lastActivityDate;
            updated = true;
        }
        if (req.completionDate != null) {
            sheet.completionDate = req.completionDate;
            updated = true;
        }

        // 6) Verificar se algum campo foi realmente alterado
        if (!updated) {
            return Response.status(Status.BAD_REQUEST)
                    .entity("Nenhum campo de atualização fornecido")
                    .build();
        }

        // 7) Persistir alterações
        datastore.put(sheet.toEntity(datastore));

        return Response.ok(sheet).build();
    }


    @GET
    @Path("/export/{id}")
    @Produces(MediaType.APPLICATION_JSON)
    public Response exportExecutionSheet(@HeaderParam("Authorization") String auth,
                                         @PathParam("id") String id) {
        // 1) Autenticação
        String token = extractToken(auth);
        if (token == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("Token ausente ou inválido")
                    .build();
        }

        try {
            JwtUtil.validateToken(token);
        } catch (JwtException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("Token inválido")
                    .build();
        }

        // 2) Verificar permissões: apenas SDVBO pode exportar
        if (!JwtUtil.userHasRole(token, "SDVBO")) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Acesso negado")
                    .build();
        }

        // 3) Buscar folha de execução
        Key execSheetKey = datastore.newKeyFactory()
                .setKind("ExecutionSheet")
                .newKey(id);
        Entity sheetEnt = datastore.get(execSheetKey);
        if (sheetEnt == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("Folha não encontrada")
                    .build();
        }

        ExecutionSheet sheet = ExecutionSheet.fromEntity(sheetEnt);

        // 4) Montar estrutura JSON para exportação
        ObjectNode export = mapper.createObjectNode();
        export.put("id", sheet.id);
        export.put("starting_date", formatDate(sheet.startDate));
        export.put("finishing_date", formatDate(sheet.completionDate));
        export.put("last_activity_date", formatDate(sheet.lastActivityDate));
        export.put("observations", sheet.observations != null ? sheet.observations : "");

        ArrayNode operationsNode = export.putArray("operations");
        ArrayNode polygonsNode = export.putArray("polygons_operations");

        // 5) Buscar operações associadas à folha
        Query<Entity> opQuery = Query.newEntityQueryBuilder()
                .setKind("OperationExecution")
                .setFilter(StructuredQuery.PropertyFilter.eq("executionSheetId", sheet.id))
                .build();

        QueryResults<Entity> opResults = datastore.run(opQuery);
        while (opResults.hasNext()) {
            OperationExecution opExec = OperationExecution.fromEntity(opResults.next());

            ObjectNode opJson = operationsNode.addObject();
            opJson.put("operation_code", opExec.operationId);
            opJson.put("area_ha_executed", opExec.totalExecutedArea);
            opJson.put("area_perc", opExec.percentExecuted);
            opJson.put("starting_date", formatDate(opExec.startDate));
            opJson.put("finishing_date", formatDate(opExec.completionDate));
            opJson.put("observations", opExec.observations != null ? opExec.observations : "");

            // 6) Buscar parcelas associadas à operação
            Query<Entity> parcelQuery = Query.newEntityQueryBuilder()
                    .setKind("ParcelOperationExecution")
                    .setFilter(StructuredQuery.PropertyFilter.eq("operationExecutionId", opExec.id))
                    .build();

            QueryResults<Entity> parcelResults = datastore.run(parcelQuery);
            while (parcelResults.hasNext()) {
                ParcelOperationExecution parcel = ParcelOperationExecution.fromEntity(parcelResults.next());

                // Verificar se já existe bloco para o polígono
                ObjectNode polygonBlock = null;
                for (JsonNode node : polygonsNode) {
                    if (node.has("polygon_id") &&
                            node.get("polygon_id").asText().equals(parcel.parcelId)) {
                        polygonBlock = (ObjectNode) node;
                        break;
                    }
                }

                // Criar novo bloco se necessário
                if (polygonBlock == null) {
                    polygonBlock = polygonsNode.addObject();
                    try {
                        polygonBlock.put("polygon_id", Long.parseLong(parcel.parcelId));
                    } catch (NumberFormatException e) {
                        polygonBlock.put("polygon_id", parcel.parcelId.hashCode());
                    }
                    polygonBlock.set("operations", mapper.createArrayNode());
                }

                // 7) Adicionar operação ao bloco do polígono
                ArrayNode polyOps = (ArrayNode) polygonBlock.get("operations");
                ObjectNode po = polyOps.addObject();

                try {
                    po.put("operation_id", Long.parseLong(opExec.operationId));
                } catch (NumberFormatException e) {
                    po.put("operation_id", opExec.operationId.hashCode());
                }

                po.put("status", parcel.status.name().toLowerCase());
                po.put("starting_date", formatDate(parcel.startDate));
                po.put("finishing_date", formatDate(parcel.completionDate));
                po.put("last_activity_date", formatDate(parcel.lastActivityDate));
                po.put("observations", ""); // Por enquanto vazio
                po.set("tracks", mapper.createArrayNode()); // Placeholder para trilhos
            }
        }

        // 8) Retornar JSON exportado
        return Response.ok(export.toPrettyString()).build();
    }


    private String formatDate(Date date) {
        if (date == null) return null;
        return new SimpleDateFormat("yyyy-MM-dd").format(date);
    }

    @DELETE
    @Path("/{id}")
    public Response delete(@HeaderParam("Authorization") String auth,
                           @PathParam("id") String id) {
        String token = extractToken(auth);
        if (token == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("Token ausente").build();
        }

        try {
            JwtUtil.validateToken(token);
        } catch (JwtException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("Token inválido").build();
        }

        // Permissões: apenas PRBO, SDVBO, SYSADMIN podem apagar
        List<String> userRoles = JwtUtil.getUserRoles(token);
        if (!(userRoles.contains("PRBO") || userRoles.contains("SDVBO") || userRoles.contains("SYSADMIN"))) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Sem permissões para apagar").build();
        }

        Key sheetKey = esKeyFactory.newKey(id);
        Entity sheet = datastore.get(sheetKey);

        if (sheet == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("Folha não encontrada").build();
        }

        // Se não for admin ou SDVBO, tem de ser o dono
        String username = JwtUtil.getUsername(token);
        if (!(userRoles.contains("SYSADMIN") || userRoles.contains("SDVBO"))) {
            if (!sheet.getString("associatedUser").equals(username)) {
                return Response.status(Response.Status.FORBIDDEN)
                        .entity("Apenas o criador pode apagar esta folha").build();
            }
        }

        Transaction txn = datastore.newTransaction();
        try {
            // 🔹 1. Buscar todas as OperationExecution desta folha
            Query<Entity> opQuery = Query.newEntityQueryBuilder()
                    .setKind("OperationExecution")
                    .setFilter(PropertyFilter.eq("executionSheetId", id))
                    .build();

            List<Key> opKeys = new ArrayList<>();
            List<String> opIds = new ArrayList<>();

            QueryResults<Entity> opResults = datastore.run(opQuery);
            while (opResults.hasNext()) {
                Entity opEntity = opResults.next();
                opKeys.add(opEntity.getKey());
                opIds.add(opEntity.getKey().getName()); // ou getId() dependendo de como guardas
            }

            // 🔹 2. Para cada OperationExecution, buscar ParcelOperationExecutions
            List<Key> parcelKeys = new ArrayList<>();
            List<String> parcelIds = new ArrayList<>();

            for (String opId : opIds) {
                Query<Entity> parcelQuery = Query.newEntityQueryBuilder()
                        .setKind("ParcelOperationExecution")
                        .setFilter(PropertyFilter.eq("operationExecutionId", opId))
                        .build();

                QueryResults<Entity> parcelResults = datastore.run(parcelQuery);
                while (parcelResults.hasNext()) {
                    Entity parcelEntity = parcelResults.next();
                    parcelKeys.add(parcelEntity.getKey());
                    parcelIds.add(parcelEntity.getKey().getName());
                }
            }

            // 🔹 3. Para cada ParcelOperationExecution, buscar Activities
            List<Key> activityKeys = new ArrayList<>();

            for (String parcelId : parcelIds) {
                Query<Entity> activityQuery = Query.newEntityQueryBuilder()
                        .setKind("Activity")
                        .setFilter(PropertyFilter.eq("parcelOperationExecutionId", parcelId))
                        .build();

                QueryResults<Entity> activityResults = datastore.run(activityQuery);
                while (activityResults.hasNext()) {
                    Entity actEntity = activityResults.next();
                    activityKeys.add(actEntity.getKey());
                }
            }

            // 🔹 4. Apagar tudo dentro da mesma transação
            if (!activityKeys.isEmpty()) {
                txn.delete(activityKeys.toArray(new Key[0]));
            }
            if (!parcelKeys.isEmpty()) {
                txn.delete(parcelKeys.toArray(new Key[0]));
            }
            if (!opKeys.isEmpty()) {
                txn.delete(opKeys.toArray(new Key[0]));
            }

            // 🔹 5. Finalmente, apagar a folha principal
            txn.delete(sheetKey);

            txn.commit();

            return Response.ok("Folha de execução e dados associados removidos com sucesso").build();

        } catch (Exception e) {
            if (txn.isActive()) txn.rollback();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("Erro ao remover folha e dados relacionados: " + e.getMessage()).build();
        }

    }

}