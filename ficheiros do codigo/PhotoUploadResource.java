package pt.unl.fct.di.apdc.trailblaze.resources;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.List;
import java.util.UUID;
import java.util.logging.Logger;

import org.glassfish.jersey.media.multipart.FormDataContentDisposition;
import org.glassfish.jersey.media.multipart.FormDataParam;

import com.google.cloud.storage.Blob;
import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;

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

    private static final Logger logger = Logger.getLogger(PhotoUploadResource.class.getName());
    
    // Google Cloud Storage configuration
    private static final String PROJECT_ID = "trailblaze-460312";
    private static final String BUCKET_NAME = "trailblaze-photos";
    private static final Storage storage = StorageOptions.newBuilder()
            .setProjectId(PROJECT_ID)
            .build()
            .getService();
    
    // Fallback local directory for development
    private static final String UPLOAD_DIR = determineUploadDir();
    private static final String BASE_URL = determineBaseUrl();
    private static final boolean USE_CLOUD_STORAGE = isRunningOnAppEngine();

    private static boolean isRunningOnAppEngine() {
        return System.getenv("GAE_SERVICE") != null;
    }

    private static String determineUploadDir() {
        // Check if running on App Engine
        String gaeService = System.getenv("GAE_SERVICE");
        if (gaeService != null) {
            // On App Engine, use WEB-INF directory which is writable
            // This is one of the few directories App Engine allows writing to
            return "./WEB-INF/uploads/photos";
        } else {
            // Local development - use a local directory
            return "./uploads/photos";
        }
    }

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
            String uploadDir = determineUploadDir();
            java.nio.file.Path uploadPath = Paths.get(uploadDir);
            
            logger.info("Attempting to create upload directory: " + uploadPath.toAbsolutePath());
            
            // Create parent directories if they don't exist
            if (uploadPath.getParent() != null) {
                Files.createDirectories(uploadPath.getParent());
            }
            
            Files.createDirectories(uploadPath);
            
            // Test write permissions
            java.nio.file.Path testFile = uploadPath.resolve("test-write.tmp");
            try {
                Files.write(testFile, "test".getBytes());
                Files.deleteIfExists(testFile);
                logger.info("Upload directory created successfully with write permissions: " + uploadPath.toAbsolutePath());
            } catch (IOException writeTest) {
                logger.warning("Upload directory created but write test failed: " + writeTest.getMessage());
            }
            
        } catch (IOException e) {
            logger.severe("Failed to create upload directory: " + e.getMessage());
            e.printStackTrace();
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
                logger.warning("Upload attempt with invalid filename");
                return Response.status(Response.Status.BAD_REQUEST)
                               .entity("{\"error\":\"Nome de ficheiro inválido.\"}").build();
            }
            
            // Validate file type
            if (!isValidImageFile(fileName)) {
                logger.warning("Upload attempt with invalid file type: " + fileName);
                return Response.status(Response.Status.BAD_REQUEST)
                               .entity("{\"error\":\"Tipo de ficheiro não suportado. Use JPG, PNG ou JPEG.\"}").build();
            }
            
            String fileExtension = getFileExtension(fileName);
            String uniqueFileName = UUID.randomUUID().toString() + fileExtension;
            String photoUrl;
            
            if (USE_CLOUD_STORAGE) {
                // Use Google Cloud Storage
                photoUrl = uploadToCloudStorage(fileInputStream, uniqueFileName, fileName);
            } else {
                // Use local file system (development)
                photoUrl = uploadToLocalStorage(fileInputStream, uniqueFileName, fileName);
            }
            
            logger.info("Photo uploaded successfully: " + photoUrl);
            
            return Response.ok()
                    .entity("{\"photoUrl\":\"" + photoUrl + "\", \"message\":\"Upload successful\", \"fileName\":\"" + fileName + "\"}")
                    .build();
                    
        } catch (IOException e) {
            logger.severe("IO Error during file upload: " + e.getMessage());
            e.printStackTrace();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                           .entity("{\"error\":\"Erro no upload: " + e.getMessage() + "\"}").build();
        } catch (Exception e) {
            logger.severe("Unexpected error during file upload: " + e.getMessage());
            e.printStackTrace();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                           .entity("{\"error\":\"Erro inesperado no upload.\"}").build();
        }
    }

    private String uploadToCloudStorage(InputStream fileInputStream, String uniqueFileName, String originalFileName) throws IOException {
        try {
            BlobId blobId = BlobId.of(BUCKET_NAME, uniqueFileName);
            BlobInfo blobInfo = BlobInfo.newBuilder(blobId)
                    .setContentType(getContentType(originalFileName))
                    .build();
            
            // Upload to Cloud Storage
            storage.create(blobInfo, fileInputStream.readAllBytes());
            
            logger.info("File uploaded to Cloud Storage: " + uniqueFileName);
            
            // Return public URL
            return String.format("https://storage.googleapis.com/%s/%s", BUCKET_NAME, uniqueFileName);
            
        } catch (Exception e) {
            logger.severe("Failed to upload to Cloud Storage: " + e.getMessage());
            throw new IOException("Cloud Storage upload failed", e);
        }
    }
    
    private String uploadToLocalStorage(InputStream fileInputStream, String uniqueFileName, String originalFileName) throws IOException {
        java.nio.file.Path filePath = Paths.get(UPLOAD_DIR, uniqueFileName);
        logger.info("Attempting to save file locally: " + filePath.toAbsolutePath());
        
        // Ensure parent directory exists
        Files.createDirectories(filePath.getParent());
        
        // Copy with replace existing to avoid conflicts
        Files.copy(fileInputStream, filePath, StandardCopyOption.REPLACE_EXISTING);
        
        // Verify file was written
        if (!Files.exists(filePath) || Files.size(filePath) == 0) {
            logger.severe("File was not written successfully: " + filePath.toAbsolutePath());
            throw new IOException("Failed to write file locally");
        }
        
        logger.info("File uploaded locally: " + uniqueFileName + " (size: " + Files.size(filePath) + " bytes)");
        
        return BASE_URL + "/rest/photos/view/" + uniqueFileName;
    }

    @GET
    @jakarta.ws.rs.Path("/view/{filename}")
    @Produces("image/*")
    public Response viewPhoto(@PathParam("filename") String filename) {
        logger.info("Photo requested: " + filename);
        
        try {
            if (USE_CLOUD_STORAGE) {
                return viewPhotoFromCloudStorage(filename);
            } else {
                return viewPhotoFromLocalStorage(filename);
            }
        } catch (Exception e) {
            logger.severe("Error serving photo " + filename + ": " + e.getMessage());
            e.printStackTrace();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                          .entity("{\"error\":\"Erro ao carregar foto.\"}")
                          .build();
        }
    }
    
    private Response viewPhotoFromCloudStorage(String filename) throws IOException {
        try {
            BlobId blobId = BlobId.of(BUCKET_NAME, filename);
            Blob blob = storage.get(blobId);
            
            if (blob == null || !blob.exists()) {
                logger.warning("Photo not found in Cloud Storage: " + filename);
                return Response.status(Response.Status.NOT_FOUND)
                              .entity("{\"error\":\"Foto não encontrada.\"}")
                              .build();
            }
            
            byte[] imageData = blob.getContent();
            String mimeType = blob.getContentType();
            
            if (mimeType == null) {
                mimeType = getContentType(filename);
            }
            
            logger.info("Serving photo from Cloud Storage: " + filename + " (" + imageData.length + " bytes, " + mimeType + ")");
            
            return Response.ok(imageData, mimeType)
                    .header("Cache-Control", "public, max-age=31536000")
                    .header("Content-Length", imageData.length)
                    .build();
                    
        } catch (Exception e) {
            logger.severe("Error retrieving photo from Cloud Storage: " + e.getMessage());
            throw new IOException("Cloud Storage retrieval failed", e);
        }
    }
    
    private Response viewPhotoFromLocalStorage(String filename) throws IOException {
        java.nio.file.Path filePath = Paths.get(UPLOAD_DIR, filename);
        
        logger.info("Looking for photo at: " + filePath.toAbsolutePath());
        
        if (!Files.exists(filePath)) {
            logger.warning("Photo not found: " + filePath.toAbsolutePath());
            return Response.status(Response.Status.NOT_FOUND)
                          .entity("{\"error\":\"Foto não encontrada.\"}")
                          .build();
        }
        
        byte[] imageData = Files.readAllBytes(filePath);
        String mimeType = Files.probeContentType(filePath);
        
        if (mimeType == null) {
            mimeType = getContentType(filename);
        }
        
        logger.info("Serving photo: " + filename + " (" + imageData.length + " bytes, " + mimeType + ")");
        
        return Response.ok(imageData, mimeType)
                .header("Cache-Control", "public, max-age=31536000")
                .header("Content-Length", imageData.length)
                .build();
    }

    // Add diagnostic endpoint
    @GET
    @jakarta.ws.rs.Path("/debug/list")
    @Produces(MediaType.APPLICATION_JSON)
    public Response listPhotos(@HeaderParam("Authorization") String auth) {
        // Quick auth check
        if (auth == null || !auth.startsWith("Bearer ")) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        }
        
        try {
            java.nio.file.Path uploadPath = Paths.get(UPLOAD_DIR);
            
            if (!Files.exists(uploadPath)) {
                return Response.ok("{\"error\":\"Upload directory does not exist\",\"path\":\"" + 
                    uploadPath.toAbsolutePath() + "\"}").build();
            }
            
            java.util.List<String> files = Files.list(uploadPath)
                .filter(Files::isRegularFile)
                .map(path -> path.getFileName().toString())
                .collect(java.util.stream.Collectors.toList());
            
            String json = "{\"uploadDir\":\"" + uploadPath.toAbsolutePath() + 
                         "\",\"fileCount\":" + files.size() + 
                         ",\"files\":[" + 
                         files.stream().map(f -> "\"" + f + "\"").collect(java.util.stream.Collectors.joining(",")) +
                         "]}";
            
            return Response.ok(json).build();
            
        } catch (IOException e) {
            return Response.ok("{\"error\":\"" + e.getMessage() + "\"}").build();
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
    
    private String getContentType(String fileName) {
        if (fileName == null) return "image/jpeg";
        String lowerFileName = fileName.toLowerCase();
        if (lowerFileName.endsWith(".jpg") || lowerFileName.endsWith(".jpeg")) {
            return "image/jpeg";
        } else if (lowerFileName.endsWith(".png")) {
            return "image/png";
        } else {
            return "image/jpeg"; // Default
        }
    }
}
