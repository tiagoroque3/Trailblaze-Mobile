package pt.unl.fct.di.apdc.trailblaze.resources;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import com.google.cloud.Timestamp;
import com.google.cloud.datastore.Datastore;
import com.google.cloud.datastore.DatastoreException;
import com.google.cloud.datastore.DatastoreOptions;
import com.google.cloud.datastore.Entity;
import com.google.cloud.datastore.Key;
import com.google.cloud.datastore.KeyFactory;
import com.google.cloud.datastore.ListValue;
import com.google.cloud.datastore.Query;
import com.google.cloud.datastore.QueryResults;
import com.google.cloud.datastore.StringValue;
import com.google.cloud.datastore.StructuredQuery;
import com.google.cloud.datastore.StructuredQuery.PropertyFilter;
import com.google.cloud.datastore.Value;

import jakarta.json.Json;
import jakarta.json.JsonArrayBuilder;
import jakarta.json.JsonObjectBuilder;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.PATCH;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import pt.unl.fct.di.apdc.trailblaze.util.AddInfoRequest;
import pt.unl.fct.di.apdc.trailblaze.util.JwtUtil;
import pt.unl.fct.di.apdc.trailblaze.util.NotifyOutUtil;
import pt.unl.fct.di.apdc.trailblaze.util.ParcelExecutionStatus;
import pt.unl.fct.di.apdc.trailblaze.util.Role;



@Path("/operations")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class OperationResource {

    private final Datastore datastore = DatastoreOptions.getDefaultInstance().getService();
    private final KeyFactory workSheetKeyFactory = datastore.newKeyFactory().setKind("WorkSheet");
    private final KeyFactory executionSheetKeyFactory = datastore.newKeyFactory().setKind("ExecutionSheet");
    private final KeyFactory operationExecutionKeyFactory = datastore.newKeyFactory().setKind("OperationExecution");
    private final KeyFactory parcelExecutionKeyFactory = datastore.newKeyFactory().setKind("ParcelOperationExecution");
    private final KeyFactory actKeyFactory = datastore.newKeyFactory().setKind("Activity");

    
    private boolean hasRole(String token, Role required) {
        if (token == null || !token.startsWith("Bearer ")) {
            System.err.println("Token mal formatado ou ausente.");
            return false;
        }
        token = token.substring("Bearer ".length());
        List<String> userRolesStr = JwtUtil.getUserRoles(token);
        if (userRolesStr == null || userRolesStr.isEmpty()) {
            System.err.println("Token inválido ou sem roles.");
            return false;
        }

        for (String roleStr : userRolesStr) {
            try {
                Role userRole = Role.valueOf(roleStr);
                if (userRole.ordinal() >= required.ordinal()) {
                    return true;
                }
            } catch (IllegalArgumentException e) {
                System.err.println("Role desconhecida: " + roleStr);
            }
        }

        return false;
    }


    private String getUsername(String token) {
        return JwtUtil.getUsername(token);
    }

    /**
     * Valida se um utilizador tem um role específico
     * @param username Username ou email do utilizador
     * @param requiredRole Role que deve ter
     * @return Entity do utilizador se for válido, null caso contrário
     */
    private Entity validateUserWithRole(String userId, String requiredRole) {
        try {
            // Tentar buscar apenas por ID da conta (chave da entidade)
            Key userKey = datastore.newKeyFactory().setKind("Account").newKey(userId);
            Entity userEntity = datastore.get(userKey);
            
            if (userEntity == null) {
                return null; // Utilizador não encontrado
            }
            
            // Verificar se tem o role requerido
            if (userEntity.contains("roles")) {
                List<Value<?>> roles = userEntity.getList("roles");
                for (Value<?> roleValue : roles) {
                    if (requiredRole.equals(((StringValue) roleValue).get())) {
                        return userEntity; // Utilizador válido com o role
                    }
                }
            }
            
            return null; // Utilizador não tem o role requerido
            
        } catch (Exception e) {
            System.err.println("Erro ao validar utilizador: " + e.getMessage());
            return null;
        }
    }

    /**
     * Verifica se dois usernames se referem ao mesmo utilizador
     * Compara apenas por ID da conta
     */
    private boolean isSameUser(String userId1, String userId2) {
        if (userId1 == null || userId2 == null) {
            return false;
        }
        
        // Comparação direta por ID
        return userId1.equals(userId2);
    }

    @POST
    @Path("/assign")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response assignOperationToParcels(
            @HeaderParam("Authorization") String token,
            AssignOperationRequest request
    ) {
        // 1. Verificar permissões
        if (!hasRole(token, Role.PRBO)) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Permissões insuficientes.").build();
        }

        // 2. Validar dados do pedido
        if (request == null || request.executionSheetId == null || request.operationId == null ||
            request.parcelExecutions == null || request.parcelExecutions.isEmpty()) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("Dados incompletos no pedido.").build();
        }

        // 3. Procurar a OperationExecution correspondente
        Query<Entity> opExecQuery = Query.newEntityQueryBuilder()
                .setKind("OperationExecution")
                .setFilter(StructuredQuery.CompositeFilter.and(
                        PropertyFilter.eq("executionSheetId", request.executionSheetId),
                        PropertyFilter.eq("operationId", request.operationId) // operationId é da folha de obra
                ))
                .build();

        QueryResults<Entity> opExecResults = datastore.run(opExecQuery);
        if (!opExecResults.hasNext()) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("OperationExecution não encontrada para os IDs fornecidos.").build();
        }

        Entity opExecEntity = opExecResults.next();
        String opExecId = opExecEntity.getKey().getName();
        String associatedExecutionSheetId = opExecEntity.getString("executionSheetId");

        // 4. Obter a ExecutionSheet para saber a WorkSheet original
        Key execSheetKey = executionSheetKeyFactory.newKey(associatedExecutionSheetId);
        Entity executionSheet;
        try {
            executionSheet = datastore.get(execSheetKey);
        } catch (DatastoreException e) {
            return Response.serverError().entity("Erro ao obter ExecutionSheet: " + e.getMessage()).build();
        }

        if (executionSheet == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("ExecutionSheet não encontrada.").build();
        }

        String workSheetIdStr = executionSheet.getString("associatedWorkSheetId");
        long workSheetId = Long.parseLong(workSheetIdStr);
        Key workSheetKey = workSheetKeyFactory.newKey(workSheetId);


        Instant now = Instant.now();
        List<Entity> parcelsToSave = new ArrayList<>();
        List<String> newParcelIds = new ArrayList<>();

        for (ParcelExecutionData parcel : request.parcelExecutions) {
            if (parcel.parcelId == null || parcel.parcelId.isEmpty()) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("ID da parcela inválido.").build();
            }

            if (parcel.assignedUsername == null || parcel.assignedUsername.isEmpty()) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("Username do PO para assignar é obrigatório.").build();
            }

            // 5. Validar que o username tem role PO
            Entity poUserEntity = validateUserWithRole(parcel.assignedUsername, "PO");
            if (poUserEntity == null) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("Username '" + parcel.assignedUsername + "' não encontrado ou não tem role PO.").build();
            }

            // 6. Verificar se parcela existe na WorkSheet associada
            long parcelIdLong;
            try {
                parcelIdLong = Long.parseLong(parcel.parcelId);
            } catch (NumberFormatException e) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("ID da parcela inválido (esperado número): " + parcel.parcelId).build();
            }

            Key parcelKey = Key.newBuilder(workSheetKey, "Parcel", parcelIdLong).build();
            Entity parcelEntity;
            try {
                parcelEntity = datastore.get(parcelKey);
            } catch (DatastoreException e) {
                return Response.serverError().entity("Erro ao verificar parcela: " + e.getMessage()).build();
            }

            if (parcelEntity == null) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("Parcela " + parcel.parcelId + " não existe na folha de obra.").build();
            }
            
            if (parcel.area == null) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("Área esperada em parcela " + parcel.parcelId + " está ausente.").build();
            }


            // 7. Verificar se parcela já está atribuída a esta OperationExecution
            Query<Entity> checkQuery = Query.newEntityQueryBuilder()
                    .setKind("ParcelOperationExecution")
                    .setFilter(StructuredQuery.CompositeFilter.and(
                            PropertyFilter.eq("operationExecutionId", opExecId),
                            PropertyFilter.eq("parcelId", parcel.parcelId)
                    ))
                    .build();

            if (datastore.run(checkQuery).hasNext()) {
                return Response.status(Response.Status.CONFLICT)
                        .entity("Parcela " + parcel.parcelId + " já foi atribuída a esta operação.").build();
            }

            // 8. Criar ParcelOperationExecution
            String parcelOpExecId = UUID.randomUUID().toString();
            Key newParcelKey = parcelExecutionKeyFactory.newKey(parcelOpExecId);

            Entity parcelExecEntity = Entity.newBuilder(newParcelKey)
                    .set("operationExecutionId", opExecId)
                    .set("parcelId", parcel.parcelId)
                    .set("assignedUsername", parcel.assignedUsername)
                    .set("startDate", Timestamp.ofTimeSecondsAndNanos(now.getEpochSecond(), 0))
                    .set("lastActivityDate", Timestamp.ofTimeSecondsAndNanos(now.getEpochSecond(), 0))
                    .set("status", "ASSIGNED")
                    .set("expectedArea", parcel.area != null ? parcel.area : 0.0)
                    .set("executedArea", 0.0)
                    .set("activityIds", ListValue.of(Collections.emptyList()))
                    .build();

            parcelsToSave.add(parcelExecEntity);
            newParcelIds.add(parcelOpExecId);
        }

        try {
            // 8. Guardar os ParcelOperationExecutions
            datastore.put(parcelsToSave.toArray(new Entity[0]));

            // 9. Atualizar OperationExecution com os novos parcelOperationExecutionIds
            List<Value<String>> existingIds = opExecEntity.contains("parcelOperationExecutionIds")
                    ? opExecEntity.getList("parcelOperationExecutionIds")
                    : new ArrayList<>();

            List<Value<String>> updatedIds = new ArrayList<>(existingIds);
            for (String id : newParcelIds) {
                updatedIds.add(StringValue.of(id));
            }

            Entity.Builder updatedBuilder = Entity.newBuilder(opExecEntity)
            	    .set("parcelOperationExecutionIds", ListValue.of(updatedIds))
            	    .set("lastActivityDate", Timestamp.ofTimeSecondsAndNanos(now.getEpochSecond(), 0));

            	// Só definir startDate se ainda não estiver definido
            	if (!opExecEntity.contains("startDate")) {
            	    updatedBuilder.set("startDate", Timestamp.ofTimeSecondsAndNanos(now.getEpochSecond(), 0));
            	}

            	Entity updatedOpExec = updatedBuilder.build();
            	datastore.put(updatedOpExec);


            return Response.ok(Map.of(
                    "message", "Parcelas atribuídas com sucesso.",
                    "operationExecutionId", opExecId,
                    "parcelOperationExecutionIds", newParcelIds
            )).build();

        } catch (DatastoreException e) {
            return Response.serverError()
                    .entity("Erro ao persistir dados: " + e.getMessage()).build();
        }
    }



    @POST
    @Path("/{operationId}/start")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response startActivity(
            @HeaderParam("Authorization") String token,
            @PathParam("operationId") String operationExecutionId,
            StartActivityRequest request
    ) {
        if (!hasRole(token, Role.PO)) {
            return Response.status(Response.Status.FORBIDDEN).entity("Permissões insuficientes.").build();
        }

        if (request.parcelOperationExecutionId == null || request.parcelOperationExecutionId.isEmpty()) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("O campo parcelOperationExecutionId é obrigatório.").build();
        }

        String userId = getUsername(token);
        Instant now = Instant.now();

        // 1. Obter a ParcelOperationExecution diretamente pela chave
        Key parcelOpKey = parcelExecutionKeyFactory.newKey(request.parcelOperationExecutionId);
        Entity parcelExecEntity = datastore.get(parcelOpKey);

        if (parcelExecEntity == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("ParcelOperationExecution não encontrada.").build();
        }

        // 2. Validar que pertence à OperationExecution correta
        if (!operationExecutionId.equals(parcelExecEntity.getString("operationExecutionId"))) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("ParcelOperationExecution não pertence à OperationExecution especificada.").build();
        }

        // 2.1. Verificar se o PO tem acesso a esta ParcelOperationExecution
        if (parcelExecEntity.contains("assignedUsername")) {
            String assignedUsername = parcelExecEntity.getString("assignedUsername");
            if (assignedUsername != null && !assignedUsername.isEmpty() && !isSameUser(userId, assignedUsername)) {
                return Response.status(Response.Status.FORBIDDEN)
                        .entity("Não tem permissão para iniciar atividades nesta parcela. Parcela atribuída a: " + assignedUsername).build();
            }
        }
        // Se não tem assignedUsername (parcelas antigas), qualquer PO pode acessar

        // 3. Criar a Activity ligada à ParcelOperationExecution
        String activityId = UUID.randomUUID().toString();
        Key activityKey = actKeyFactory.newKey(activityId);

        Entity activity = Entity.newBuilder(activityKey)
                .set("parcelOperationExecutionId", request.parcelOperationExecutionId)
                .set("operatorId", userId)
                .set("startTime", Timestamp.ofTimeSecondsAndNanos(now.getEpochSecond(), 0))
                .setNull("endTime")
                .set("observations", StringValue.of(sanitize("Início da atividade por " + userId)))
                .set("gpsTrack", StringValue.of(""))  // ou null se preferires
                .set("photoUrls", ListValue.of(Collections.emptyList()))
                .build();

        try {
            // 4. Guardar a atividade
            datastore.put(activity);

            // 5. Atualizar a ParcelOperationExecution
            List<Value<String>> existingActivityIds = parcelExecEntity.contains("activityIds")
                    ? parcelExecEntity.getList("activityIds")
                    : new ArrayList<>();

            List<Value<String>> updatedIds = new ArrayList<>(existingActivityIds);
            updatedIds.add(StringValue.of(activityId));

            Entity updatedParcelExec = Entity.newBuilder(parcelExecEntity)
                    .set("activityIds", ListValue.of(updatedIds))
                    .set("lastActivityDate", Timestamp.ofTimeSecondsAndNanos(now.getEpochSecond(), 0))
                    .set("status", StringValue.of("IN_PROGRESS"))
                    .build();

            datastore.put(updatedParcelExec);

            // 6. Atualizar a OperationExecution
            Key opKey = operationExecutionKeyFactory.newKey(operationExecutionId);
            Entity opEntity = datastore.get(opKey);
            if (opEntity != null) {
                Entity updatedOp = Entity.newBuilder(opEntity)
                        .set("lastActivityDate", Timestamp.ofTimeSecondsAndNanos(now.getEpochSecond(), 0))
                        .build();
                datastore.put(updatedOp);
            }

            return Response.ok(Map.of(
                    "message", "Atividade iniciada com sucesso",
                    "activityId", activityId
            )).build();

        } catch (DatastoreException e) {
            return Response.serverError().entity("Erro ao iniciar atividade: " + e.getMessage()).build();
        }
    }

    
  
    @POST
    @Path("/{operationId}/stop")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response stopActivity(
            @HeaderParam("Authorization") String token,
            @PathParam("operationId") String operationExecutionId,
            StopActivityRequest request
    ) {
        if (!hasRole(token, Role.PO)) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Permissões insuficientes.").build();
        }

        String userId = getUsername(token);

        if (request.activityId == null || request.activityId.isEmpty()) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("O campo activityId é obrigatório.").build();
        }

        // 1. Buscar a Activity
        Key activityKey = actKeyFactory.newKey(request.activityId);
        Entity activity = datastore.get(activityKey);

        if (activity == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("Atividade não encontrada.").build();
        }

        // 2. Validar que o utilizador é o operador da atividade
        if (!userId.equals(activity.getString("operatorId"))) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Não autorizado para parar esta atividade.").build();
        }

        // 3. Validar que a atividade ainda não terminou
        if (activity.contains("endTime") && activity.getTimestamp("endTime") != null) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("Atividade já finalizada.").build();
        }

        // 4. Obter a ParcelOperationExecution ligada à Activity
        String parcelOpExecId = activity.getString("parcelOperationExecutionId");
        Key parcelOpKey = parcelExecutionKeyFactory.newKey(parcelOpExecId);
        Entity parcelExec = datastore.get(parcelOpKey);

        if (parcelExec == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("ParcelOperationExecution associada não encontrada.").build();
        }

        // 4.1. Verificar se o PO tem acesso a esta ParcelOperationExecution
        if (parcelExec.contains("assignedUsername")) {
            String assignedUsername = parcelExec.getString("assignedUsername");
            if (assignedUsername != null && !assignedUsername.isEmpty() && !isSameUser(userId, assignedUsername)) {
                return Response.status(Response.Status.FORBIDDEN)
                        .entity("Não tem permissão para parar atividades nesta parcela. Parcela atribuída a: " + assignedUsername).build();
            }
        }
        // Se não tem assignedUsername (parcelas antigas), qualquer PO pode acessar

        // 5. Validar se a ParcelOperationExecution está ligada à OperationExecution do URL
        if (!parcelExec.getString("operationExecutionId").equals(operationExecutionId)) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("ParcelOperationExecution não pertence à OperationExecution especificada.").build();
        }

        Instant now = Instant.now();

        try {
            // 6. Atualizar a Activity com o endTime
            Entity updatedActivity = Entity.newBuilder(activity)
                    .set("endTime", Timestamp.ofTimeSecondsAndNanos(now.getEpochSecond(), 0))
                    .build();
            datastore.put(updatedActivity);

            // 7. Verificar se todas as atividades da parcel estão finalizadas
            @SuppressWarnings("unchecked")
            List<Value<String>> valueList = (List<Value<String>>) (List<?>) parcelExec.getList("activityIds");

            List<String> activityIds = valueList.stream()
                    .map(Value::get)
                    .collect(Collectors.toList());


            boolean allFinished = true;
            for (String id : activityIds) {
                Entity act = datastore.get(actKeyFactory.newKey(id));
                if (!act.contains("endTime") || act.getTimestamp("endTime") == null) {
                    allFinished = false;
                    break;
                }
            }

            String newStatus = allFinished ? ParcelExecutionStatus.EXECUTED.name()
                                           : ParcelExecutionStatus.IN_PROGRESS.name();

            // 8. Atualizar a ParcelOperationExecution
            Entity updatedParcelExec = Entity.newBuilder(parcelExec)
                    .set("lastActivityDate", Timestamp.ofTimeSecondsAndNanos(now.getEpochSecond(), 0))
                    .set("status", StringValue.of(newStatus))
                    .build();
            datastore.put(updatedParcelExec);

            // 9. Atualizar a OperationExecution
            Key opKey = operationExecutionKeyFactory.newKey(operationExecutionId);
            Entity opEntity = datastore.get(opKey);
            if (opEntity != null) {
                Entity updatedOp = Entity.newBuilder(opEntity)
                        .set("lastActivityDate", Timestamp.ofTimeSecondsAndNanos(now.getEpochSecond(), 0))
                        .build();
                datastore.put(updatedOp);
            }

            // 10. Verificar notificações se a parcela foi concluída
            if (allFinished) {
                // Notificação 1: Operação concluída nesta parcela
                NotifyOutUtil.checkAndNotifyOperationParcelEnd(operationExecutionId, parcelOpExecId);
                
                // Notificação 2: Verificar se a operação está totalmente concluída
                NotifyOutUtil.checkAndNotifyOperationEnd(operationExecutionId);
            }
            return Response.ok(Map.of(
                    "message", "Atividade finalizada com sucesso",
                    "activityId", request.activityId
            )).build();

        } catch (DatastoreException e) {
            return Response.serverError()
                    .entity("Erro ao terminar atividade: " + e.getMessage()).build();
        }
    }




    
    @GET
    @Path("/{operationExecutionId}/activities")
    @Produces(MediaType.APPLICATION_JSON)
    public Response viewActivitiesForOperation(
            @HeaderParam("Authorization") String token,
            @PathParam("operationExecutionId") String operationExecutionId) {

        if (!hasRole(token, Role.PO) && !hasRole(token, Role.PRBO)) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Acesso negado.").build();
        }

        // Validar existência da OperationExecution
        Key opExecKey = operationExecutionKeyFactory.newKey(operationExecutionId);
        Entity opExecEntity = datastore.get(opExecKey);
        if (opExecEntity == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("OperationExecution não encontrado.").build();
        }

        JsonArrayBuilder resultArray = Json.createArrayBuilder();

        // Buscar todas as ParcelOperationExecution associadas
        Query<Entity> parcelQuery = Query.newEntityQueryBuilder()
                .setKind("ParcelOperationExecution")
                .setFilter(PropertyFilter.eq("operationExecutionId", operationExecutionId))
                .build();

        QueryResults<Entity> parcelResults = datastore.run(parcelQuery);

        while (parcelResults.hasNext()) {
            Entity parcelEntity = parcelResults.next();
            String parcelOpExecId = parcelEntity.getKey().getName();

            // Buscar atividades desta parcela
            Query<Entity> activityQuery = Query.newEntityQueryBuilder()
                    .setKind("Activity")
                    .setFilter(PropertyFilter.eq("parcelOperationExecutionId", parcelOpExecId))
                    .build();

            QueryResults<Entity> activities = datastore.run(activityQuery);

            while (activities.hasNext()) {
                Entity activity = activities.next();

                JsonObjectBuilder activityJson = Json.createObjectBuilder()
                        .add("activityId", activity.getKey().getName())
                        .add("parcelOperationExecutionId", parcelOpExecId)
                        .add("parcelId", parcelEntity.getString("parcelId"))
                        .add("operatorId", activity.getString("operatorId"))
                        .add("startTime",
                        	    activity.contains("startTime") && activity.getTimestamp("startTime") != null
                        	        ? activity.getTimestamp("startTime").toString()
                        	        : "")
                        .add("endTime",
                        	    activity.contains("endTime") && activity.getTimestamp("endTime") != null
                        	        ? activity.getTimestamp("endTime").toString()
                        	        : "")
                        .add("observations", activity.getString("observations"))
                        .add("gpsTrack", activity.getString("gpsTrack"));

                if (activity.contains("photoUrls")) {
                    JsonArrayBuilder photos = Json.createArrayBuilder();
                    for (Value<?> value : activity.getList("photoUrls")) {
                        if (value instanceof StringValue) {
                            photos.add(((StringValue) value).get());
                        }
                    }

                    activityJson.add("photoUrls", photos);
                } else {
                    activityJson.add("photoUrls", Json.createArrayBuilder());
                }

                resultArray.add(activityJson);
            }
        }

        return Response.ok(resultArray.build()).build();
    }

    @GET
    @Path("/{operationExecutionId}/parcels/{parcelOperationExecutionId}/activities")
    @Produces(MediaType.APPLICATION_JSON)
    public Response viewActivitiesForOperationParcel(
            @HeaderParam("Authorization") String token,
            @PathParam("operationExecutionId") String operationExecutionId,
            @PathParam("parcelOperationExecutionId") String parcelOperationExecutionId) {

        // Verificar roles de acesso
        if (!hasRole(token, Role.PO) && !hasRole(token, Role.PRBO)) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Acesso negado.").build();
        }

        // Validar existência da OperationExecution
        Key opExecKey = operationExecutionKeyFactory.newKey(operationExecutionId);
        Entity opExecEntity = datastore.get(opExecKey);
        if (opExecEntity == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("OperationExecution não encontrado.").build();
        }

        // Validar existência da ParcelOperationExecution e que pertence à OperationExecution dada
        Key parcelOpExecKey = parcelExecutionKeyFactory.newKey(parcelOperationExecutionId);
        Entity parcelOpExecEntity = datastore.get(parcelOpExecKey);
        if (parcelOpExecEntity == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("ParcelOperationExecution não encontrado.").build();
        }
        // Verificar se pertence à operação correta
        String opExecIdOfParcel = parcelOpExecEntity.getString("operationExecutionId");
        if (!operationExecutionId.equals(opExecIdOfParcel)) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("ParcelOperationExecution não pertence à OperationExecution fornecida.").build();
        }

        // Buscar atividades dessa parcela
        Query<Entity> activityQuery = Query.newEntityQueryBuilder()
                .setKind("Activity")
                .setFilter(PropertyFilter.eq("parcelOperationExecutionId", parcelOperationExecutionId))
                .build();

        QueryResults<Entity> activities = datastore.run(activityQuery);

        JsonArrayBuilder resultArray = Json.createArrayBuilder();

        while (activities.hasNext()) {
            Entity activity = activities.next();

            JsonObjectBuilder activityJson = Json.createObjectBuilder()
                    .add("activityId", activity.getKey().getName())
                    .add("parcelOperationExecutionId", parcelOperationExecutionId)
                    .add("parcelId", parcelOpExecEntity.getString("parcelId"))
                    .add("operatorId", activity.getString("operatorId"))
                    .add("startTime",
                    	    activity.contains("startTime") && activity.getTimestamp("startTime") != null
                    	        ? activity.getTimestamp("startTime").toString()
                    	        : "")
                    .add("endTime",
                    	    activity.contains("endTime") && activity.getTimestamp("endTime") != null
                    	        ? activity.getTimestamp("endTime").toString()
                    	        : "")
                    .add("observations", activity.getString("observations"))
                    .add("gpsTrack", activity.getString("gpsTrack"));

            if (activity.contains("photoUrls")) {
                JsonArrayBuilder photos = Json.createArrayBuilder();
                for (Value<?> value : activity.getList("photoUrls")) {
                    if (value instanceof StringValue) {
                        photos.add(((StringValue) value).get());
                    }
                }
                activityJson.add("photoUrls", photos);
            } else {
                activityJson.add("photoUrls", Json.createArrayBuilder());
            }

            resultArray.add(activityJson);
        }

        return Response.ok(resultArray.build()).build();
    }




    @POST
    @Path("/activity/addinfo")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response addActivityInfo(
            @HeaderParam("Authorization") String token,
            AddInfoRequest req
    ) {
        if (!hasRole(token, Role.PO) && !hasRole(token, Role.PRBO) && !hasRole(token, Role.SYSADMIN)) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Permissões insuficientes.").build();
        }

        if (req == null || !req.isValid()) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("Pedido inválido ou campos em falta.").build();
        }

        try {
            System.out.println("=== AddActivityInfo Debug ===");
            System.out.println("Activity ID: " + req.activityId);
            System.out.println("Photos count: " + (req.photos != null ? req.photos.size() : 0));
            
            // Procurar a atividade pelo ID
            Key activityKey = actKeyFactory.newKey(req.activityId);
            Entity activityEntity = datastore.get(activityKey);

            if (activityEntity == null) {
                System.out.println("Activity not found: " + req.activityId);
                return Response.status(Response.Status.NOT_FOUND)
                        .entity("Atividade não encontrada.").build();
            }

            System.out.println("Activity found, checking if finished...");

            // Verificar ownership para POs
            String currentUser = getUsername(token);
            if (hasRole(token, Role.PO) && !hasRole(token, Role.PRBO) && !hasRole(token, Role.SYSADMIN)) {
                // Se é apenas PO, verificar se tem acesso à ParcelOperationExecution
                String parcelOpExecId = activityEntity.getString("parcelOperationExecutionId");
                if (parcelOpExecId != null) {
                    Key parcelOpKey = parcelExecutionKeyFactory.newKey(parcelOpExecId);
                    Entity parcelExec = datastore.get(parcelOpKey);
                    
                    if (parcelExec != null && parcelExec.contains("assignedUsername")) {
                        String assignedUsername = parcelExec.getString("assignedUsername");
                        if (assignedUsername != null && !assignedUsername.isEmpty() && !currentUser.equals(assignedUsername)) {
                            return Response.status(Response.Status.FORBIDDEN)
                                    .entity("Não tem permissão para adicionar informações a atividades nesta parcela. Parcela atribuída a: " + assignedUsername).build();
                        }
                    }
                    // Se não tem assignedUsername (parcelas antigas), qualquer PO pode acessar
                }
            }

            // Verificar se a atividade já terminou (só pode adicionar info se terminou)
            if (!activityEntity.contains("endTime") || activityEntity.getTimestamp("endTime") == null) {
                System.out.println("Activity is still running");
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("A atividade ainda está em curso. Só é possível adicionar informações após terminar.").build();
            }

            System.out.println("Activity is finished, updating...");

            // Atualizar campos
            Entity.Builder updatedActivityBuilder = Entity.newBuilder(activityEntity);

            // Update observations if provided
            if (req.observations != null && !req.observations.trim().isEmpty()) {
                updatedActivityBuilder.set("observations", StringValue.of(req.observations));
            }

            // Update GPS tracks if provided
            if (req.gpsTracks != null && !req.gpsTracks.isEmpty()) {
                // Join GPS tracks with comma separator
                String gpsTracksStr = String.join(",", req.gpsTracks);
                updatedActivityBuilder.set("gpsTrack", StringValue.of(gpsTracksStr));
            }

            // Update photos if provided
            if (req.photos != null && !req.photos.isEmpty()) {
                System.out.println("Processing " + req.photos.size() + " photos");
                
                // Get existing photos first
                List<String> allPhotos = new ArrayList<>();
                if (activityEntity.contains("photoUrls")) {
                    for (Value<?> v : activityEntity.getList("photoUrls")) {
                        String existingPhoto = ((StringValue) v).get();
                        if (existingPhoto != null && !existingPhoto.trim().isEmpty()) {
                            allPhotos.add(existingPhoto);
                        }
                    }
                }
                System.out.println("Found " + allPhotos.size() + " existing photos");
                
                // Add new photos to existing ones
                for (String newPhoto : req.photos) {
                    if (newPhoto != null && !newPhoto.trim().isEmpty() && !allPhotos.contains(newPhoto)) {
                        allPhotos.add(newPhoto);
                    }
                }
                
                System.out.println("Total photos after merge: " + allPhotos.size());
                
                // Convert to ListValue
                List<Value<String>> photoValues = allPhotos.stream()
                        .map(photo -> StringValue.newBuilder(photo).setExcludeFromIndexes(true).build())
                        .collect(Collectors.toList());
                
                // Create ListValue with non-indexed string values
                updatedActivityBuilder.set("photoUrls", ListValue.of(photoValues));
            }

            System.out.println("Saving to datastore...");

            // Save the updated activity
            datastore.put(updatedActivityBuilder.build());

            System.out.println("Successfully saved!");

            return Response.ok(Map.of(
                    "message", "Informações adicionadas à atividade.",
                    "activityId", req.activityId
            )).build();

        } catch (DatastoreException e) {
            System.err.println("Erro no Datastore ao atualizar atividade: " + e.getMessage());
            e.printStackTrace();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("Erro interno ao atualizar informações da atividade: " + e.getMessage()).build();
        } catch (Exception e) {
            System.err.println("Erro geral ao atualizar atividade: " + e.getMessage());
            e.printStackTrace();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("Erro interno: " + e.getMessage()).build();
        }
    }

    @POST
    @Path("/activity/deletephoto")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response deleteActivityPhoto(
            @HeaderParam("Authorization") String token,
            Map<String, String> request
    ) {
        if (!hasRole(token, Role.PO) && !hasRole(token, Role.PRBO) && !hasRole(token, Role.SYSADMIN)) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Permissões insuficientes.").build();
        }

        String activityId = request.get("activityId");
        String photoUrl = request.get("photoUrl");

        if (activityId == null || activityId.trim().isEmpty() || 
            photoUrl == null || photoUrl.trim().isEmpty()) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("Activity ID e Photo URL são obrigatórios.").build();
        }

        try {
            System.out.println("=== DeleteActivityPhoto Debug ===");
            System.out.println("Activity ID: " + activityId);
            System.out.println("Photo URL to delete: " + photoUrl);
            
            // Find the activity
            Key activityKey = actKeyFactory.newKey(activityId);
            Entity activityEntity = datastore.get(activityKey);

            if (activityEntity == null) {
                System.out.println("Activity not found: " + activityId);
                return Response.status(Response.Status.NOT_FOUND)
                        .entity("Atividade não encontrada.").build();
            }

            // Check permissions (same as addActivityInfo)
            String currentUser = getUsername(token);
            if (hasRole(token, Role.PO) && !hasRole(token, Role.PRBO) && !hasRole(token, Role.SYSADMIN)) {
                String parcelOpExecId = activityEntity.getString("parcelOperationExecutionId");
                if (parcelOpExecId != null) {
                    Key parcelOpKey = parcelExecutionKeyFactory.newKey(parcelOpExecId);
                    Entity parcelExec = datastore.get(parcelOpKey);
                    
                    if (parcelExec != null && parcelExec.contains("assignedUsername")) {
                        String assignedUsername = parcelExec.getString("assignedUsername");
                        if (assignedUsername != null && !assignedUsername.isEmpty() && !currentUser.equals(assignedUsername)) {
                            return Response.status(Response.Status.FORBIDDEN)
                                    .entity("Não tem permissão para modificar fotos desta atividade.").build();
                        }
                    }
                }
            }

            // Get existing photos
            List<String> existingPhotos = new ArrayList<>();
            if (activityEntity.contains("photoUrls")) {
                for (Value<?> v : activityEntity.getList("photoUrls")) {
                    String existingPhoto = ((StringValue) v).get();
                    if (existingPhoto != null && !existingPhoto.trim().isEmpty()) {
                        existingPhotos.add(existingPhoto);
                    }
                }
            }

            System.out.println("Found " + existingPhotos.size() + " existing photos");

            // Remove the specified photo
            boolean removed = existingPhotos.remove(photoUrl);
            
            if (!removed) {
                return Response.status(Response.Status.NOT_FOUND)
                        .entity("Foto não encontrada na atividade.").build();
            }

            System.out.println("Photo removed. Remaining photos: " + existingPhotos.size());

            // Update the activity with the new photo list
            Entity.Builder updatedActivityBuilder = Entity.newBuilder(activityEntity);
            
            List<Value<String>> photoValues = existingPhotos.stream()
                    .map(photo -> StringValue.newBuilder(photo).setExcludeFromIndexes(true).build())
                    .collect(Collectors.toList());
            
            updatedActivityBuilder.set("photoUrls", ListValue.of(photoValues));

            // Save the updated activity
            datastore.put(updatedActivityBuilder.build());

            System.out.println("Successfully deleted photo!");

            return Response.ok(Map.of(
                    "message", "Foto removida com sucesso.",
                    "activityId", activityId,
                    "remainingPhotos", existingPhotos.size()
            )).build();

        } catch (DatastoreException e) {
            System.err.println("Erro no Datastore ao remover foto: " + e.getMessage());
            e.printStackTrace();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("Erro interno ao remover foto: " + e.getMessage()).build();
        } catch (Exception e) {
            System.err.println("Erro geral ao remover foto: " + e.getMessage());
            e.printStackTrace();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("Erro interno: " + e.getMessage()).build();
        }
    }

    @PATCH
    @Path("/edit-operation-execution")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response editOperationExecution(
            @HeaderParam("Authorization") String token,
            EditOperationExecutionRequest request
    ) {
        // 1. Verificar permissões
        if (!hasRole(token, Role.PRBO) && !hasRole(token, Role.SDVBO)) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("Permissões insuficientes.").build();
        }

        // 2. Validar request
        if (request == null || request.operationExecutionId == null) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("ID da operação de execução é obrigatório.").build();
        }

        // 3. Obter a entidade OperationExecution
        Key operationExecutionKey = operationExecutionKeyFactory.newKey(request.operationExecutionId);
        Entity operationExecutionEntity;
        try {
            operationExecutionEntity = datastore.get(operationExecutionKey);
            if (operationExecutionEntity == null) {
                return Response.status(Response.Status.NOT_FOUND)
                        .entity("OperationExecution não encontrada.").build();
            }
        } catch (DatastoreException e) {
            return Response.serverError()
                    .entity("Erro ao obter OperationExecution: " + e.getMessage()).build();
        }

        // 4. Construir entidade atualizada
        Entity.Builder updatedBuilder = Entity.newBuilder(operationExecutionEntity);

        if (request.predictedEndDate != null) {
            updatedBuilder.set("predictedEndDate", Timestamp.of(request.predictedEndDate));
        }

        if (request.estimatedDurationMinutes != null) {
            updatedBuilder.set("estimatedDurationMinutes", request.estimatedDurationMinutes);
        }

        if (request.expectedTotalArea != null) {
            updatedBuilder.set("expectedTotalArea", request.expectedTotalArea);
        }

        if (request.observations != null) {
            updatedBuilder.set("observations", StringValue.newBuilder(request.observations).setExcludeFromIndexes(true).build());
        }

        // 5. Guardar
        try {
            datastore.put(updatedBuilder.build());
            return Response.ok(Map.of(
                    "message", "OperationExecution atualizada com sucesso.",
                    "operationExecutionId", request.operationExecutionId
            )).build();
        } catch (DatastoreException e) {
            return Response.serverError()
                    .entity("Erro ao atualizar OperationExecution: " + e.getMessage()).build();
        }
    }

    @GET
    @Path("/{operationExecutionId}/parcels")
    @Produces(MediaType.APPLICATION_JSON)
    public Response listParcelsForOperation(
        @HeaderParam("Authorization") String token,
        @PathParam("operationExecutionId") String operationExecutionId) {

        // Permission Check
        if (!hasRole(token, Role.PRBO)) {
            return Response.status(Response.Status.FORBIDDEN)
                .entity("Insufficient permissions.").build();
        }

        // Fetch all ParcelOperationExecution entities for the given operation
        Query<Entity> query = Query.newEntityQueryBuilder()
            .setKind("ParcelOperationExecution")
            .setFilter(PropertyFilter.eq("operationExecutionId", operationExecutionId))
            .build();

        QueryResults<Entity> results = datastore.run(query);

        // Build the JSON response array
        JsonArrayBuilder parcelsArray = Json.createArrayBuilder();
        while (results.hasNext()) {
            Entity entity = results.next();
            // We only need a subset of data for the list view
            JsonObjectBuilder parcelJson = Json.createObjectBuilder()
                .add("parcelId", entity.getString("parcelId"))
                .add("status", entity.getString("status"))
                .add("operationId", entity.getString("operationExecutionId"));
        
            parcelsArray.add(parcelJson);
        }

        return Response.ok(parcelsArray.build()).build();
    }

    
    // DTOs
    public static class AssignOperationRequest {
        public String executionSheetId;
        public String operationId;
        public List<ParcelExecutionData> parcelExecutions;
        public double expectedTotalArea;
    }

    public static class ParcelExecutionData {
        public String parcelId;
        public Double area;
        public String assignedUsername; // Username do PO que será assigned
    }

    public static class StartActivityRequest {
        public String parcelOperationExecutionId;
    }

    public static class StopActivityRequest {
        public String activityId;
    }


    private String sanitize(String input) {
        return input == null ? "" : input.replaceAll("<", "&lt;").replaceAll(">", "&gt;");
    }
    
    public static class EditOperationExecutionRequest {
        public String operationExecutionId;

        public Date predictedEndDate;
        public Long estimatedDurationMinutes;
        public Double expectedTotalArea;
        public String observations;
    }



}