package pt.unl.fct.di.apdc.trailblaze.util;


import com.google.cloud.datastore.*;
import java.util.Date;
import java.util.List;
import java.util.ArrayList;
import java.util.UUID;
import java.util.stream.Collectors;

import com.google.cloud.Timestamp;



public class ExecutionSheet {
    public String id;
    public String title;
    public String description;
    public String associatedUser;
    public String associatedWorkSheetId;

    public Date startDate;
    public Date lastActivityDate;
    public Date completionDate;

    public String observations;
    public ExecutionSheetState state; // PENDING, IN_PROGRESS, COMPLETED

    // Operações executadas nesta folha (apenas IDs se não embutires)
    public List<String> operationExecutionIds;

    public ExecutionSheet() {
        this.id = UUID.randomUUID().toString();
        this.state = ExecutionSheetState.PENDING;
        this.operationExecutionIds = new ArrayList<>();
        this.startDate = new Date();
    }

    public ExecutionSheet(String title, String description, String user, String workSheetId) {
        this();
        this.title = title;
        this.description = description;
        this.associatedUser = user;
        this.associatedWorkSheetId = workSheetId;
    }



    public Entity toEntity(Datastore datastore) {
        Key key = datastore.newKeyFactory().setKind("ExecutionSheet").newKey(id);
        Entity.Builder builder = Entity.newBuilder(key)
            .set("title", title)
            .set("description", description)
            .set("associatedUser", associatedUser)
            .set("associatedWorkSheetId", associatedWorkSheetId)
            .set("state", state.name())
            .set("observations", StringValue.of(observations == null ? "" : observations));

        if (startDate != null) builder.set("startDate", Timestamp.of(startDate));
        if (lastActivityDate != null) builder.set("lastActivityDate", Timestamp.of(lastActivityDate));
        if (completionDate != null) builder.set("completionDate", Timestamp.of(completionDate));

        List<Value<String>> ops = new ArrayList<>();
        for (String opId : operationExecutionIds) {
            ops.add(StringValue.of(opId));
        }
        builder.set("operationExecutionIds", ListValue.of(ops));

        return builder.build();
    }

    public static ExecutionSheet fromEntity(Entity entity) {
        ExecutionSheet sheet = new ExecutionSheet();
        sheet.id = entity.getKey().getName();
        sheet.title = entity.contains("title") ? entity.getString("title") : "";
        sheet.description = entity.contains("description") ? entity.getString("description") : "";
        sheet.associatedUser = entity.contains("associatedUser") ? entity.getString("associatedUser") : "";
        sheet.associatedWorkSheetId = entity.contains("associatedWorkSheetId") ? entity.getString("associatedWorkSheetId") : "";
        sheet.state = entity.contains("state") ? ExecutionSheetState.valueOf(entity.getString("state")) : ExecutionSheetState.PENDING;
        sheet.observations = entity.contains("observations") ? entity.getString("observations") : "";

        if (entity.contains("startDate")) sheet.startDate = entity.getTimestamp("startDate").toDate();
        if (entity.contains("lastActivityDate")) sheet.lastActivityDate = entity.getTimestamp("lastActivityDate").toDate();
        if (entity.contains("completionDate")) sheet.completionDate = entity.getTimestamp("completionDate").toDate();

        sheet.operationExecutionIds = new ArrayList<>();
        if (entity.contains("operationExecutionIds")) {
            for (Value<?> v : entity.getList("operationExecutionIds")) {
                sheet.operationExecutionIds.add(((StringValue) v).get());
            }
        }

        return sheet;
    }
}