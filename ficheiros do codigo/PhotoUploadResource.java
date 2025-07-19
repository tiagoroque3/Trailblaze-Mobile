package pt.unl.fct.di.apdc.trailblaze.resources;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;
import java.util.UUID;

import org.glassfish.jersey.media.multipart.FormDataContentDisposition;
import org.glassfish.jersey.media.multipart.FormDataParam;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import pt.unl.fct.di.apdc.trailblaze.util.JwtUtil;

@jakarta.ws.rs.Path("/photos")
@Consumes(MediaType.MULTIPART_FORM_DATA)
@Produces(MediaType.APPLICATION_JSON)
public class PhotoUploadResource {

    private static final String UPLOAD_DIR = "/tmp/trailblaze-photos";
    private static final String BASE_URL = determineBaseUrl();

    private static String determineBaseUrl() {
        // Try to get from environment variable first
        String baseUrl = System.getenv("APP_BASE_URL");
        if (baseUrl != null && !baseUrl.isEmpty()) {
            return baseUrl;
        }
        
        // Check if running on App Engine
        String gaeService = System.getenv("GAE_SERVICE");
        if (gaeService != null) {
            // Running on App Engine - use production URL
            return "https://trailblaze-460312.oa.r.appspot.com";
        }
        
        // Check if running locally
        String port = System.getProperty("server.port", "8080");
        return "http://localhost:" + port + "/Firstwebapp";
    }

    static {
        try {
            Files.createDirectories(Paths.get(UPLOAD_DIR));
        } catch (IOException e) {
            System.err.println("Failed to create upload directory: " + e.getMessage());
        }
    }

    @POST
    @jakarta.ws.rs.Path("/upload")
    public Response uploadPhoto(
            @HeaderParam("Authorization") String auth,
            @FormDataParam("file") InputStream fileInputStream,
            @FormDataParam("file") FormDataContentDisposition fileMetaData) {

        // Validate token and permissions
        String token = (auth != null) ? auth.replaceFirst("(?i)^Bearer\\s+", "").trim() : null;
        if (token == null || token.isEmpty()) {
            return Response.status(Response.Status.UNAUTHORIZED).entity("Token ausente.").build();
        }

        List<String> roles;
        try {
            var claims = JwtUtil.validateToken(token).getBody();
            @SuppressWarnings("unchecked")
            List<String> rolesList = claims.containsKey("roles")
                    ? (List<String>) claims.get("roles", List.class)
                    : List.of(claims.get("role", String.class));
            roles = rolesList;
        } catch (Exception e) {
            return Response.status(Response.Status.UNAUTHORIZED).entity("Token inválido.").build();
        }

        if (!hasValidRole(roles)) {
            return Response.status(Response.Status.FORBIDDEN)
                           .entity("Permissões insuficientes.").build();
        }

        if (fileInputStream == null || fileMetaData == null) {
            return Response.status(Response.Status.BAD_REQUEST)
                           .entity("Ficheiro não fornecido.").build();
        }

        try {
            String fileName = fileMetaData.getFileName();
            if (fileName == null || fileName.trim().isEmpty()) {
                return Response.status(Response.Status.BAD_REQUEST)
                               .entity("{\"error\":\"Nome de ficheiro inválido.\"}").build();
            }
            
            // Validate file type
            if (!isValidImageFile(fileName)) {
                return Response.status(Response.Status.BAD_REQUEST)
                               .entity("{\"error\":\"Tipo de ficheiro não suportado. Use JPG, PNG ou JPEG.\"}").build();
            }
            
            String fileExtension = getFileExtension(fileName);
            String uniqueFileName = UUID.randomUUID().toString() + fileExtension;
            
            java.nio.file.Path filePath = Paths.get(UPLOAD_DIR, uniqueFileName);
            Files.copy(fileInputStream, filePath);
            
            String photoUrl = BASE_URL + "/rest/photos/view/" + uniqueFileName;
            
            System.out.println("Photo uploaded successfully: " + photoUrl);
            
            return Response.ok()
                    .entity("{\"photoUrl\":\"" + photoUrl + "\", \"message\":\"Upload successful\", \"fileName\":\"" + fileName + "\"}")
                    .build();
                    
        } catch (IOException e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                           .entity("Erro no upload: " + e.getMessage()).build();
        }
    }

    @GET
    @jakarta.ws.rs.Path("/view/{filename}")
    @Produces("image/*")
    public Response viewPhoto(@PathParam("filename") String filename) {
        try {
            java.nio.file.Path filePath = Paths.get(UPLOAD_DIR, filename);
            
            if (!Files.exists(filePath)) {
                return Response.status(Response.Status.NOT_FOUND).build();
            }
            
            byte[] imageData = Files.readAllBytes(filePath);
            String mimeType = Files.probeContentType(filePath);
            
            return Response.ok(imageData, mimeType).build();
            
        } catch (IOException e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR).build();
        }
    }

    private boolean hasValidRole(List<String> roles) {
        return roles.contains("PO") || roles.contains("PRBO") || roles.contains("SYSADMIN") ||
               roles.contains("SYSBO") || roles.contains("SMBO") || roles.contains("SDVBO");
    }
    
    private boolean isValidImageFile(String fileName) {
        if (fileName == null) return false;
        String lowerFileName = fileName.toLowerCase();
        return lowerFileName.endsWith(".jpg") || lowerFileName.endsWith(".jpeg") || 
               lowerFileName.endsWith(".png");
    }
    
    private String getFileExtension(String fileName) {
        if (fileName == null || !fileName.contains(".")) {
            return ".jpg"; // Default extension
        }
        int lastDotIndex = fileName.lastIndexOf('.');
        return fileName.substring(lastDotIndex);
    }
}
