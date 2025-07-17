package pt.unl.fct.di.apdc.trailblaze.util;

import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.databind.node.*;

import com.google.cloud.Timestamp;
import com.google.cloud.datastore.*;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 *  Utils / DAO-lite para tudo o que é Folha de Obra:
 *   • parse + validação do GeoJSON recebido no IMP-FO
 *   • construção de entidades Datastore
 *   • conversões de entidades → JSON para VIEW-GEN-FO / VIEW-DET-FO
 */
public final class WorkSheetUtil {

    /* ------------------------------------------------------------------ */
    /*  --------------------------  CONFIG  ----------------------------- */
    /* ------------------------------------------------------------------ */

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final DateTimeFormatter ISO_DATE =
            DateTimeFormatter.ISO_LOCAL_DATE; // "yyyy-MM-dd"

    private WorkSheetUtil() {}                // static-only util

    /* ------------------------------------------------------------------ */
    /*  ----------------------  DTO & PARSING  -------------------------- */
    /* ------------------------------------------------------------------ */

    /** DTO intermédio usado durante o import (IMP-FO) */
    public record ParsedWS(long id,
                           ObjectNode meta,
                           ArrayNode operations,
                           ArrayNode features) {}

    /**
     *  Faz parse ao GeoJSON, valida regras de negócio obrigatórias
     *  e devolve a estrutura pronta a ser convertida em entidades.
     *  Lança IllegalArgumentException se algo falhar.
     */
    public static ParsedWS parseAndValidate(String rawGeoJson) {

        try {
            JsonNode root  = MAPPER.readTree(rawGeoJson);

            /* --- metadata obrigatória --- */
            ObjectNode meta = expectObject(root, "metadata");
            long id = expectLong(meta, "id");

            /* --- operações 1-5 --- */
            ArrayNode ops = (ArrayNode) meta.path("operations");
            if (ops == null || ops.size() < 1 || ops.size() > 5)
                throw new IllegalArgumentException(
                        "Campo \"operations\" deve conter 1 a 5 entradas");

            /* --- features obrigatórias --- */
            ArrayNode feats = (ArrayNode) root.path("features");
            if (feats == null || feats.isEmpty())
                throw new IllegalArgumentException("Campo \"features\" está vazio/ausente");

            return new ParsedWS(id, meta, ops, feats);

        } catch (IllegalArgumentException e) {
            throw e; // re-lança sem embrulho
        } catch (Exception e) {
            throw new IllegalArgumentException("GeoJSON inválido: " + e.getMessage(), e);
        }
    }

    /* ------------------------------------------------------------------ */
    /*  ---------------  ENTITY BUILDERS (IMP-FO)  ---------------------- */
    /* ------------------------------------------------------------------ */

    public static Entity buildWorkSheetEntity(ParsedWS dto,
                                              Key wsKey,
                                              String importedBy) {

        ObjectNode m = dto.meta;

        return Entity.newBuilder(wsKey)
                .set("startingDate"     , parseDate(m, "starting_date"))
                .set("finishingDate"    , parseDate(m, "finishing_date"))
                .set("issueDate"        , parseDate(m, "issue_date"))
                .set("awardDate"        , parseDate(m, "award_date"))
                .set("serviceProviderId", m.get("service_provider_id").asLong())
                .set("posaCode"         , expectText(m,"posa_code"))
                .set("posaDescription"  , expectText(m,"posa_description"))
                .set("pospCode"         , expectText(m,"posp_code"))
                .set("pospDescription"  , expectText(m,"posp_description"))
                .set("importedBy"       , importedBy)
                .set("importTime"       , Timestamp.now())
                .build();
    }
    public static List<Entity> buildOperationEntities(ParsedWS dto, Key wsKey) {

        List<Entity> list = new ArrayList<>();

        // Define o ancestor como a folha de obra
        PathElement ancestor = PathElement.of("WorkSheet", wsKey.getId());

        // Cria a KeyFactory com o ancestor definido
        KeyFactory kf = datastore().newKeyFactory()
                .addAncestor(ancestor)
                .setKind("Operation");

        int order = 1;
        for (JsonNode o : dto.operations) {
            // Deixa o Datastore gerar o ID automaticamente (sem passar id explícito)
            Key opKey = kf.newKey(UUID.randomUUID().toString());

            Entity e = Entity.newBuilder(opKey)
                    .set("operationCode", expectText(o, "operation_code"))
                    .set("description", expectText(o, "operation_description"))
                    .set("areaHa", o.get("area_ha").asDouble())
                    .set("order", order++)
                    .build();

            list.add(e);
        }

        return list;
    }

    public static List<Entity> buildParcelEntities(ParsedWS dto, Key wsKey) {

        List<Entity> list = new ArrayList<>();
        PathElement ancestor = PathElement.of("WorkSheet", wsKey.getId());

        KeyFactory kf = datastore().newKeyFactory()
                .addAncestor(ancestor)
                .setKind("Parcel");

        for (JsonNode f : dto.features) {
        	ObjectNode props = expectObject(f, "properties");

            /*
             *  Some GeoJSON files label the polygon identifier simply as
             *  "id" (inside properties or at the feature level) instead of
             *  "polygon_id". This implementation now tries both options so that
             *  worksheets coming from different sources can be imported.
             */

            JsonNode polyNode = props.get("polygon_id");
            if (polyNode == null || !polyNode.isIntegralNumber())
                polyNode = props.get("id");
            if ((polyNode == null || !polyNode.isIntegralNumber()) &&
                    f.has("id") && f.get("id").isIntegralNumber())
                polyNode = f.get("id");

            int polygonId = polyNode != null && polyNode.isIntegralNumber()
                    ? polyNode.asInt() : 0;

            // geometry stored exactly as received to avoid losing precision
            StringValue geom = StringValue.newBuilder(f.get("geometry").toString())
                    .setExcludeFromIndexes(true)
                    .build();
            
            String aigp = props.has("aigp") && props.get("aigp").isTextual() ? props.get("aigp").asText() : "";
            String rpid = props.has("rural_property_id") && props.get("rural_property_id").isTextual()
                    ? props.get("rural_property_id").asText() : "";
            

            Entity p = Entity.newBuilder(kf.newKey(polygonId))
            		   .set("polygonId", polygonId)
                       .set("aigp", aigp)
                       .set("ruralPropertyId", rpid)
                       .set("geometry", geom)
                    .build();

            list.add(p);
        }
        return list;
    }

    /* ------------------------------------------------------------------ */
    /*  ------------  ENTITY  →  JSON (VIEWs)  -------------------------- */
    /* ------------------------------------------------------------------ */

    /** JSON “genérico” (VIEW-GEN-FO) */
    public static ObjectNode toGenericJson(Entity ws) {

        ObjectNode n = MAPPER.createObjectNode();
        n.put("id", ws.getKey().getId());

        n.put("startingDate"    , tsToIso(ws.getTimestamp("startingDate")));
        n.put("finishingDate"   , tsToIso(ws.getTimestamp("finishingDate")));
        n.put("issueDate"       , tsToIso(ws.getTimestamp("issueDate")));
        n.put("awardDate"       , tsToIso(ws.getTimestamp("awardDate")));
        n.put("serviceProviderId", ws.getLong("serviceProviderId"));

        ObjectNode posa = n.putObject("posa");
        posa.put("code"        , ws.getString("posaCode"));
        posa.put("description" , ws.getString("posaDescription"));

        ObjectNode posp = n.putObject("posp");
        posp.put("code"        , ws.getString("pospCode"));
        posp.put("description" , ws.getString("pospDescription"));

        return n;
    }

    /** JSON completo (VIEW-DET-FO) */
    public static ObjectNode toDetailJson(Entity ws,
                                          QueryResults<Entity> ops,
                                          QueryResults<Entity> parcels) {

        ObjectNode root = toGenericJson(ws);        // herda campos genéricos

        /* -------- operations -------- */
        ArrayNode arrOps = root.putArray("operations");
        ops.forEachRemaining(op -> {
            ObjectNode o = arrOps.addObject();
            o.put("code"       , op.getString("operationCode"));
            o.put("description", op.getString("description"));
            o.put("areaHa"     , op.getDouble("areaHa"));
            o.put("order"      , op.getLong("order"));
        });

        /* -------- parcels -------- */
        ArrayNode arrParcels = root.putArray("parcels");
        parcels.forEachRemaining(p -> {
            try {
                ObjectNode pr = arrParcels.addObject();
                pr.put("polygonId", p.contains("polygonId") ? p.getLong("polygonId") : 0);
                pr.put("aigp", p.contains("aigp") ? p.getString("aigp") : "");
                pr.put("ruralPropertyId", p.contains("ruralPropertyId") ? p.getString("ruralPropertyId") : "");
                String geomStr = p.contains("geometry") ? p.getString("geometry") : null;
                if (geomStr != null) {
                    try {
                        pr.set("geometry", MAPPER.readTree(geomStr));
                    } catch (Exception ex) {
                        pr.put("geometry", (String)null);
                    }
                } else {
                    pr.put("geometry", (String)null);
                }
            } catch(Exception e) {
                System.err.println("Erro ao processar parcela: " + e.getMessage());
                // Ignora parcela malformada
            }
        });

        return root;
    }

    /* ------------------------------------------------------------------ */
    /*  ----------------------------  HELPERS  -------------------------- */
    /* ------------------------------------------------------------------ */

    private static Datastore datastore() {
        return DatastoreOptions.getDefaultInstance().getService();
    }

    private static String tsToIso(Timestamp ts) {
        return ts == null ? null : ts.toSqlTimestamp().toLocalDateTime().toString();
    }

    /* --- tiny validators --- */
    private static ObjectNode expectObject(JsonNode parent, String field) {
        JsonNode n = parent.get(field);
        if (n == null || !n.isObject())
            throw new IllegalArgumentException("Campo \"" + field + "\" é obrigatório e deve ser objecto");
        return (ObjectNode) n;
    }

    private static String expectText(JsonNode parent, String field) {
        JsonNode n = parent.get(field);
        if (n == null || !n.isTextual())
            throw new IllegalArgumentException("Campo \"" + field + "\" é obrigatório e deve ser textual");
        return n.asText();
    }

    private static long expectLong(JsonNode parent, String field) {
        JsonNode n = parent.get(field);
        if (n == null || !n.isIntegralNumber())
            throw new IllegalArgumentException("Campo \"" + field + "\" é obrigatório e deve ser número inteiro");
        return n.asLong();
    }

    private static Timestamp parseDate(ObjectNode meta, String field) {
        String yyyyMMdd = expectText(meta, field);                // valida presença
        LocalDate d = LocalDate.parse(yyyyMMdd, ISO_DATE);        // lança se inválido
        return Timestamp.parseTimestamp(d + "T00:00:00Z");
    }
}