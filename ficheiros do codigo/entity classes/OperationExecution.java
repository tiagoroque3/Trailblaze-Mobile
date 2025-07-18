package pt.unl.fct.di.apdc.trailblaze.util;

import com.google.cloud.Timestamp;
import com.google.cloud.datastore.*;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.util.Date;
import java.util.List;
import java.util.UUID;
import java.util.ArrayList;

/**
 * Representa a execução de uma operação (nível intermédio),
 * agregando as execuções por parcela.
 */
public class OperationExecution {
    public String id;
    public String executionSheetId;  // Para referência inversa
    public String operationId;       // Ligação à definição da operação na folha de obra

    public Date startDate;
    public Date lastActivityDate;
    public Date completionDate;

    public double totalExecutedArea;
    public double percentExecuted;
    public double expectedTotalArea;

    public Date predictedEndDate;
    public Long estimatedDurationMinutes;

    public String observations;

    // Parcelas executadas nesta operação (apenas IDs)
    public List<String> parcelOperationExecutionIds;

    public OperationExecution() {
        this.id = UUID.randomUUID().toString();
        this.parcelOperationExecutionIds = new ArrayList<>();
    }

    public OperationExecution(String executionSheetId, String operationId, double expectedTotalArea) {
        this();
        this.executionSheetId = executionSheetId;
        this.operationId = operationId;
        this.expectedTotalArea = expectedTotalArea;
    }



    public Entity toEntity(Datastore datastore) {
        Key key = datastore.newKeyFactory().setKind("OperationExecution").newKey(id);
        Entity.Builder builder = Entity.newBuilder(key)
            .set("executionSheetId", executionSheetId)
            .set("operationId", operationId)
            .set("expectedTotalArea", expectedTotalArea)
            .set("totalExecutedArea", totalExecutedArea)
            .set("percentExecuted", percentExecuted)
            .set("observations", StringValue.of(observations == null ? "" : observations));

        if (startDate != null) builder.set("startDate", Timestamp.of(startDate));
        if (lastActivityDate != null) builder.set("lastActivityDate", Timestamp.of(lastActivityDate));
        if (completionDate != null) builder.set("completionDate", Timestamp.of(completionDate));
        if (predictedEndDate != null) builder.set("predictedEndDate", Timestamp.of(predictedEndDate));
        if (estimatedDurationMinutes != null) builder.set("estimatedDurationMinutes", estimatedDurationMinutes);

        List<Value<String>> parcelIds = new ArrayList<>();
        for (String id : parcelOperationExecutionIds) {
            parcelIds.add(StringValue.of(id));
        }
        builder.set("parcelOperationExecutionIds", ListValue.of(parcelIds));

        return builder.build();
    }

    public static OperationExecution fromEntity(Entity entity) {
        OperationExecution op = new OperationExecution();
        op.id = entity.getKey().getName();
        op.executionSheetId = entity.getString("executionSheetId");
        op.operationId = entity.getString("operationId");
        op.expectedTotalArea = entity.getDouble("expectedTotalArea");
        op.totalExecutedArea = entity.getDouble("totalExecutedArea");
        op.percentExecuted = entity.getDouble("percentExecuted");
        op.observations = entity.getString("observations");

        if (entity.contains("startDate")) op.startDate = entity.getTimestamp("startDate").toDate();
        if (entity.contains("lastActivityDate")) op.lastActivityDate = entity.getTimestamp("lastActivityDate").toDate();
        if (entity.contains("completionDate")) op.completionDate = entity.getTimestamp("completionDate").toDate();
        if (entity.contains("predictedEndDate")) op.predictedEndDate = entity.getTimestamp("predictedEndDate").toDate();
        if (entity.contains("estimatedDurationMinutes")) op.estimatedDurationMinutes = entity.getLong("estimatedDurationMinutes");

        op.parcelOperationExecutionIds = new ArrayList<>();
        if (entity.contains("parcelOperationExecutionIds")) {
            for (Value<?> v : entity.getList("parcelOperationExecutionIds")) {
                op.parcelOperationExecutionIds.add(((StringValue) v).get());
            }
        }

        return op;
    }
}