package pt.unl.fct.di.apdc.trailblaze.util;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.UUID;

import com.google.cloud.Timestamp;
import com.google.cloud.datastore.Datastore;
import com.google.cloud.datastore.Entity;
import com.google.cloud.datastore.Key;
import com.google.cloud.datastore.ListValue;
import com.google.cloud.datastore.StringValue;
import com.google.cloud.datastore.Value;

public class ParcelOperationExecution {
    public String id;
    public String operationExecutionId;  // Ligação à execução da operação
    public String parcelId;
    public String assignedUsername; // Username do PO assigned a esta ParcelOperationExecution

    public ParcelExecutionStatus status; // PENDING, ASSIGNED, IN_PROGRESS, COMPLETED

    public Date startDate;
    public Date lastActivityDate;
    public Date completionDate;

    public double expectedArea;
    public double executedArea;

    // Atividades associadas (apenas IDs se não embutidas)
    public List<String> activityIds;

    public ParcelOperationExecution() {
        this.id = UUID.randomUUID().toString();
        this.status = ParcelExecutionStatus.PENDING;
        this.activityIds = new ArrayList<>();
    }

    public ParcelOperationExecution(String operationExecutionId, String parcelId, double expectedArea) {
        this();
        this.operationExecutionId = operationExecutionId;
        this.parcelId = parcelId;
        this.expectedArea = expectedArea;
    }

    public ParcelOperationExecution(String operationExecutionId, String parcelId, double expectedArea, String assignedUsername) {
        this();
        this.operationExecutionId = operationExecutionId;
        this.parcelId = parcelId;
        this.expectedArea = expectedArea;
        this.assignedUsername = assignedUsername;
    }

    public Entity toEntity(Datastore datastore) {
        Key key = datastore.newKeyFactory().setKind("ParcelOperationExecution").newKey(id);
        Entity.Builder builder = Entity.newBuilder(key)
            .set("operationExecutionId", operationExecutionId)
            .set("parcelId", parcelId)
            .set("status", status.name())
            .set("expectedArea", expectedArea)
            .set("executedArea", executedArea);

        if (assignedUsername != null) builder.set("assignedUsername", assignedUsername);

        if (startDate != null) builder.set("startDate", Timestamp.of(startDate));
        if (lastActivityDate != null) builder.set("lastActivityDate", Timestamp.of(lastActivityDate));
        if (completionDate != null) builder.set("completionDate", Timestamp.of(completionDate));

        List<Value<String>> activityIdsValues = new ArrayList<>();
        for (String aId : activityIds) {
            activityIdsValues.add(StringValue.of(aId));
        }
        builder.set("activityIds", ListValue.of(activityIdsValues));

        return builder.build();
    }

    public static ParcelOperationExecution fromEntity(Entity entity) {
        ParcelOperationExecution p = new ParcelOperationExecution();
        p.id = entity.getKey().getName();
        p.operationExecutionId = entity.getString("operationExecutionId");
        p.parcelId = entity.getString("parcelId");
        p.status = ParcelExecutionStatus.valueOf(entity.getString("status"));
        p.expectedArea = entity.getDouble("expectedArea");
        p.executedArea = entity.getDouble("executedArea");

        if (entity.contains("assignedUsername")) p.assignedUsername = entity.getString("assignedUsername");

        if (entity.contains("startDate")) p.startDate = entity.getTimestamp("startDate").toDate();
        if (entity.contains("lastActivityDate")) p.lastActivityDate = entity.getTimestamp("lastActivityDate").toDate();
        if (entity.contains("completionDate")) p.completionDate = entity.getTimestamp("completionDate").toDate();

        p.activityIds = new ArrayList<>();
        if (entity.contains("activityIds")) {
            for (Value<?> v : entity.getList("activityIds")) {
                p.activityIds.add(((StringValue) v).get());
            }
        }

        return p;
    }
}