package pt.unl.fct.di.apdc.trailblaze.resources;

import java.net.URL;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.HttpMethod;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import pt.unl.fct.di.apdc.trailblaze.util.JwtUtil;

@Path("/media")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class MediaResource {

    /* ------------------------ GCS ------------------------ */
    private static final Storage STORAGE = StorageOptions.getDefaultInstance().getService();
    private static final String  BUCKET  = determineBucketName();

    private static String determineBucketName() {
        // Try environment variable first
        String bucketName = System.getenv("GCS_BUCKET_NAME");
        if (bucketName != null && !bucketName.isEmpty()) {
            return bucketName;
        }
        
        // Use project ID to create default bucket name
        String projectId = System.getenv("GOOGLE_CLOUD_PROJECT");
        if (projectId != null) {
            return projectId + ".appspot.com"; // Default App Engine bucket that always exists
        }
        
        // Fallback for local development
        return "trailblaze-460312.appspot.com";
    }

    /* ----------------------- DTOs ------------------------ */
    public static class UploadRequest {
        public String fileName;     // nome original (ex.: photo.jpg)
        public String contentType;  // MIME – ex.: image/jpeg
    }
    public static class SignedUploadResponse {
        public String uploadUrl;    // URL PUT assinado (15 min)
        public String evidenceUrl;  // URL pública do ficheiro
        public SignedUploadResponse(String u, String e) { uploadUrl=u; evidenceUrl=e; }
    }

    /* ===================================================== */
    /*          POST /media/signed-upload  (PO)              */
    /* ===================================================== */
    @POST
    @Path("/signed-upload")
    public Response signedUpload(@HeaderParam("Authorization") String auth,
                                 UploadRequest req) {

        /* ---------- 1. extrair e validar token ---------- */
        String token = (auth != null) ? auth.replaceFirst("(?i)^Bearer\\s+", "").trim() : null;
        if (token == null || token.isEmpty())
            return Response.status(Response.Status.UNAUTHORIZED).entity("Token ausente.").build();

        List<String> roles;
        try {
            var claims = JwtUtil.validateToken(token).getBody();
            roles = claims.containsKey("roles")
                    ? (List<String>) claims.get("roles", List.class)
                    : List.of(claims.get("role", String.class));
        } catch (Exception e) {
            return Response.status(Response.Status.UNAUTHORIZED).entity("Token inválido: " + e.getMessage()).build();
        }

        // Allow PO and other relevant roles to upload photos
        if (!roles.contains("PO") && !roles.contains("PRBO") && !roles.contains("SYSADMIN"))
            return Response.status(Response.Status.FORBIDDEN)
                           .entity("Permissões insuficientes para upload.").build();

        /* ---------- 2. validação do pedido ---------- */
        if (req == null
            || req.fileName == null || req.fileName.isBlank()
            || req.contentType == null || req.contentType.isBlank())
            return Response.status(Response.Status.BAD_REQUEST)
                           .entity("fileName e contentType obrigatórios.").build();

        try {
            /* ---------- 3. gera URL assinado ---------- */
            String objectName = "activities/" + UUID.randomUUID() + "/" + req.fileName;

            BlobInfo blobInfo = BlobInfo.newBuilder(BUCKET, objectName)
                                        .setContentType(req.contentType)
                                        .build();

            URL signedUrl = STORAGE.signUrl(
                    blobInfo,
                    15, TimeUnit.MINUTES,
                    Storage.SignUrlOption.httpMethod(HttpMethod.PUT),
                    Storage.SignUrlOption.withContentType()          // o client tem de pôr este Content-Type
            );

            String evidenceUrl = "https://storage.googleapis.com/" + BUCKET + "/" + objectName;

            return Response.ok(new SignedUploadResponse(signedUrl.toString(), evidenceUrl)).build();
            
        } catch (Exception e) {
            System.err.println("Erro ao gerar URL assinado: " + e.getMessage());
            e.printStackTrace();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                           .entity("Erro interno: não foi possível gerar URL de upload. " + e.getMessage()).build();
        }
    }
}
