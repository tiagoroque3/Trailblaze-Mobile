package pt.unl.fct.di.apdc.trailblaze.util;

import com.google.cloud.datastore.*;
import com.google.cloud.Timestamp;


import jakarta.json.Json;
import jakarta.json.JsonObject;
import jakarta.json.JsonObjectBuilder;

import java.util.*;

import com.google.cloud.datastore.*;

import java.util.Date;
import java.util.List;
import java.util.ArrayList;

public class Activity {
    public String id;
    public String parcelOperationExecutionId;
    public String operatorId;

    public Date startTime;
    public Date endTime;

    public String observations;

    public String gpsTrack;              // Ficheiro GPX (path ou conteúdo base64, a definir)
    public List<String> photoUrls;       // URLs ou paths

    public Activity() {
        this.id = UUID.randomUUID().toString();
        this.photoUrls = new ArrayList<>();
    }

    public Activity(String parcelOperationExecutionId, String operatorId, Date startTime, Date endTime,
                    String observations, String gpsTrack, List<String> photoUrls) {
        this();
        this.parcelOperationExecutionId = parcelOperationExecutionId;
        this.operatorId = operatorId;
        this.startTime = startTime;
        this.endTime = endTime;
        this.observations = observations;
        this.gpsTrack = gpsTrack;
        this.photoUrls = photoUrls != null ? photoUrls : new ArrayList<>();
    }

    public Entity toEntity(Datastore datastore) {
        Key key = datastore.newKeyFactory().setKind("Activity").newKey(id);
        Entity.Builder builder = Entity.newBuilder(key)
            .set("parcelOperationExecutionId", parcelOperationExecutionId)
            .set("operatorId", operatorId)
            .set("startTime", Timestamp.of(startTime))
            .set("endTime", Timestamp.of(endTime))
            .set("observations", StringValue.of(observations == null ? "" : observations))
            .set("gpsTrack", StringValue.of(gpsTrack == null ? "" : gpsTrack));

        List<Value<String>> photoList = new ArrayList<>();
        for (String url : photoUrls) {
            photoList.add(StringValue.of(url));
        }
        builder.set("photoUrls", ListValue.of(photoList));

        return builder.build();
    }

    public static Activity fromEntity(Entity entity) {
        Activity a = new Activity();
        a.id = entity.getKey().getName();
        a.parcelOperationExecutionId = entity.getString("parcelOperationExecutionId");
        a.operatorId = entity.getString("operatorId");
        if (entity.contains("startTime") && entity.getTimestamp("startTime") != null) {
            a.startTime = entity.getTimestamp("startTime").toDate();
        }

        if (entity.contains("endTime") && entity.getTimestamp("endTime") != null) {
            a.endTime = entity.getTimestamp("endTime").toDate();
        }

        a.observations = entity.getString("observations");
        a.gpsTrack = entity.getString("gpsTrack");

        a.photoUrls = new ArrayList<>();
        if (entity.contains("photoUrls")) {
            for (Value<?> v : entity.getList("photoUrls")) {
                a.photoUrls.add(((StringValue) v).get());
            }
        }

        return a;
    }

  
  
}