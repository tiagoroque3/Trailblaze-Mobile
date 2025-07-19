# Multiple Photos Implementation Guide - Trailblaze

## Overview
This guide provides comprehensive implementation details for adding multiple photo upload and management functionality to mobile applications. The guide is based on the successful web implementation in the Trailblaze execution sheets system.

## Table of Contents
1. [Backend Implementation](#backend-implementation)
2. [Frontend Implementation](#frontend-implementation)
3. [State Management](#state-management)
4. [Photo Upload Strategy](#photo-upload-strategy)
5. [Delete Functionality](#delete-functionality)
6. [Error Handling](#error-handling)
7. [Testing Scenarios](#testing-scenarios)

## Backend Implementation

### 1. Photo Upload Endpoint
**Endpoint:** `POST /rest/photos/upload`

```java
@POST
@Path("/upload")
@Consumes(MediaType.MULTIPART_FORM_DATA)
@Produces(MediaType.TEXT_PLAIN)
public Response uploadPhoto(
    @FormDataParam("file") InputStream uploadedInputStream,
    @FormDataParam("file") FormDataContentDisposition fileDetail) {
    
    // Implementation handles:
    // - File validation (type, size)
    // - UUID-based naming
    // - Google Cloud Storage upload with local fallback
    // - Dynamic URL generation
    
    return Response.ok(photoUrl).build();
}
```

**Key Features:**
- **File Validation:** Accepts JPG, PNG files up to 10MB
- **Storage Strategy:** Primary GCS, fallback to local filesystem
- **URL Generation:** Dynamic base URL detection for different environments
- **UUID Naming:** Prevents conflicts and ensures uniqueness

### 2. Activity Information Endpoint (Modified)
**Endpoint:** `POST /rest/operations/activity/addinfo`

```java
@POST
@Path("/activity/addinfo")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public Response addActivityInfo(String requestBody) {
    // CRITICAL: Merge photos instead of replacing
    if (existingActivity.getPhotoUrls() != null) {
        List<String> allPhotos = new ArrayList<>(existingActivity.getPhotoUrls());
        allPhotos.addAll(activityInfo.getPhotos());
        activity.setPhotoUrls(allPhotos);
    } else {
        activity.setPhotoUrls(new ArrayList<>(activityInfo.getPhotos()));
    }
}
```

**Critical Bug Fix:**
- **Before:** `activity.setPhotoUrls(activityInfo.getPhotos())` - Replaced existing photos
- **After:** Merge existing + new photos using `ArrayList` concatenation

### 3. Photo Deletion Endpoint
**Endpoint:** `POST /rest/operations/activity/deletephoto`

```java
@POST
@Path("/activity/deletephoto")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.TEXT_PLAIN)
public Response deleteActivityPhoto(String requestBody) {
    // Permission validation
    if (!hasPermission(currentUser, activity)) {
        return Response.status(403).entity("Insufficient permissions").build();
    }
    
    // Remove specific photo URL from array
    List<String> updatedPhotos = new ArrayList<>(activity.getPhotoUrls());
    updatedPhotos.remove(photoUrl);
    activity.setPhotoUrls(updatedPhotos);
    
    return Response.ok("Photo deleted successfully").build();
}
```

## Frontend Implementation

### 1. Photo Selection Interface
```javascript
// HTML Structure
<div class="file-upload-area" onclick="selectMultiplePhotos()">
    <div class="upload-text">📷 Click to upload multiple photos</div>
    <div class="upload-hint">JPG, PNG files up to 10MB each • Hold Ctrl/Cmd to select multiple files</div>
</div>
<input type="file" id="photo-input" multiple accept="image/jpeg,image/png,image/jpg" style="display: none;">
<div id="photo-list" class="photo-preview-container"></div>
```

### 2. Photo Upload Logic
```javascript
async function uploadPhotos(files) {
    const progressContainer = document.getElementById('photo-upload-progress');
    const progressBar = progressContainer.querySelector('.progress-fill');
    
    progressContainer.style.display = 'block';
    let completed = 0;
    
    // Sequential upload to avoid overwhelming server
    for (const file of files) {
        try {
            const formData = new FormData();
            formData.append('file', file);
            
            const response = await fetch('/rest/photos/upload', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`
                },
                body: formData
            });
            
            if (response.ok) {
                const photoUrl = await response.text();
                currentUploadedPhotos.push({
                    name: file.name,
                    url: photoUrl,
                    success: true
                });
            }
        } catch (error) {
            console.error('Upload failed:', error);
        } finally {
            completed++;
            const progress = (completed / files.length) * 100;
            progressBar.style.width = `${progress}%`;
        }
    }
    
    updatePhotoListDisplay();
}
```

## State Management

### 1. Global Photo State
```javascript
// Global array to track uploaded photos across modal sessions
let currentUploadedPhotos = [];

// Initialize with existing photos when modal opens
function initializePhotoState(activityId) {
    const activity = findActivityById(activityId);
    currentUploadedPhotos = activity.photoUrls ? 
        activity.photoUrls.map(url => ({
            name: url.split('/').pop() || 'Photo',
            url: url,
            success: true
        })) : [];
}
```

### 2. Photo List Management
```javascript
function updatePhotoListDisplay() {
    const photoList = document.getElementById('photo-list');
    
    // Counter for multiple photos
    let counterHtml = '';
    if (currentUploadedPhotos.length > 1) {
        counterHtml = `
            <div class="photos-counter">
                📷 ${currentUploadedPhotos.length} photos selected
                <button type="button" onclick="clearAllPhotos()">Clear All</button>
            </div>
        `;
    }
    
    // Individual photo items
    const photosHtml = currentUploadedPhotos.map((photo, index) => `
        <div class="photo-item" data-photo-index="${index}">
            <img src="${photo.url}" alt="${photo.name}" class="photo-thumbnail" 
                 onclick="viewPhotoModal('${photo.url}')">
            <div class="photo-name">${photo.name}</div>
            <button type="button" onclick="removePhoto(${index})">×</button>
        </div>
    `).join('');
    
    photoList.innerHTML = counterHtml + photosHtml;
}
```

## Photo Upload Strategy

### 1. Sequential Processing
```javascript
// Process files one by one to avoid server overload
for (const file of files) {
    await uploadSingleFile(file);
}
```

**Benefits:**
- Prevents server timeout
- Better error handling per file
- Accurate progress tracking
- Reduced memory usage

### 2. Validation Before Upload
```javascript
function validateFiles(files) {
    const validTypes = ['image/jpeg', 'image/png', 'image/jpg'];
    const maxSize = 10 * 1024 * 1024; // 10MB
    
    return files.filter(file => {
        if (!validTypes.includes(file.type)) {
            showError(`${file.name}: Invalid file type`);
            return false;
        }
        if (file.size > maxSize) {
            showError(`${file.name}: File too large`);
            return false;
        }
        return true;
    });
}
```

### 3. Progress Tracking
```javascript
function updateProgress(completed, total, successCount) {
    const progressBar = document.querySelector('.progress-fill');
    const progressText = document.querySelector('.progress-text');
    
    const percentage = (completed / total) * 100;
    progressBar.style.width = `${percentage}%`;
    
    if (completed === total) {
        if (successCount === total) {
            progressText.textContent = `Successfully uploaded ${successCount} photos!`;
        } else {
            progressText.textContent = `Uploaded ${successCount}/${total} photos`;
        }
    } else {
        progressText.textContent = `Uploading ${completed + 1}/${total}...`;
    }
}
```

## Delete Functionality

### 1. Individual Photo Deletion
```javascript
async function deleteActivityPhoto(activityId, photoUrl, event) {
    // Prevent event bubbling
    if (event) {
        event.preventDefault();
        event.stopPropagation();
    }
    
    if (!confirm('Delete this photo? This action cannot be undone.')) {
        return;
    }
    
    try {
        const response = await fetch('/rest/operations/activity/deletephoto', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                activityId: activityId,
                photoUrl: photoUrl
            })
        });
        
        if (response.ok) {
            showMessage('Photo deleted successfully!', 'success');
            refreshActivityView();
        } else {
            showError('Failed to delete photo');
        }
    } catch (error) {
        showError('Connection error');
    }
}
```

### 2. Permission-Based UI
```javascript
function renderPhotoThumbnail(photoUrl, activityId, canDelete) {
    return `
        <div class="activity-photo-container">
            <img src="${photoUrl}" onclick="viewPhotoModal('${photoUrl}')" 
                 class="activity-photo-thumb">
            ${canDelete ? `
                <button class="delete-photo-btn" 
                        onclick="deleteActivityPhoto('${activityId}', '${photoUrl}', event)"
                        title="Delete photo">×</button>
            ` : ''}
        </div>
    `;
}
```

### 3. Photo Gallery with Delete
```javascript
function viewAllPhotos(activityId, photoUrls, canDelete) {
    const photosHtml = photoUrls.map(url => `
        <div class="photo-gallery-item">
            <img src="${url}" onclick="viewPhotoModal('${url}')" class="gallery-photo">
            ${canDelete ? `
                <button class="gallery-delete-btn" 
                        onclick="deleteActivityPhoto('${activityId}', '${url}', event)">×</button>
            ` : ''}
        </div>
    `).join('');
    
    openModal('All Photos', `
        <div class="photo-gallery">${photosHtml}</div>
        ${canDelete ? '<p>Click × on any photo to delete it</p>' : ''}
    `);
}
```

## Error Handling

### 1. Upload Error Recovery
```javascript
async function uploadWithRetry(file, maxRetries = 3) {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            return await uploadFile(file);
        } catch (error) {
            if (attempt === maxRetries) {
                throw new Error(`Upload failed after ${maxRetries} attempts: ${error.message}`);
            }
            // Wait before retry
            await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
        }
    }
}
```

### 2. Network Error Handling
```javascript
function handleNetworkError(error, operation) {
    console.error(`${operation} failed:`, error);
    
    if (error.name === 'NetworkError') {
        showError('Network connection error. Please check your internet connection.');
    } else if (error.status === 413) {
        showError('File too large. Please select smaller files.');
    } else if (error.status === 403) {
        showError('Insufficient permissions for this operation.');
    } else {
        showError(`${operation} failed. Please try again.`);
    }
}
```

### 3. File Validation Errors
```javascript
function validateAndShowErrors(files) {
    const errors = [];
    const validFiles = [];
    
    files.forEach(file => {
        if (!isValidFileType(file)) {
            errors.push(`${file.name}: Invalid file type (only JPG, PNG allowed)`);
        } else if (!isValidFileSize(file)) {
            errors.push(`${file.name}: File too large (max 10MB)`);
        } else {
            validFiles.push(file);
        }
    });
    
    if (errors.length > 0) {
        showError(errors.join('\n'));
    }
    
    return validFiles;
}
```

## Testing Scenarios

### 1. Photo Upload Tests
```javascript
// Test Cases:
// ✅ Single photo upload
// ✅ Multiple photos upload (2-10 files)
// ✅ Large file handling (>10MB rejection)
// ✅ Invalid file type rejection
// ✅ Network interruption recovery
// ✅ Duplicate photo handling
// ✅ Empty file handling
```

### 2. State Management Tests
```javascript
// Test Cases:
// ✅ Adding photos to activity with existing photos
// ✅ Adding photos to activity without existing photos
// ✅ Modal reopen maintains photo state
// ✅ Clear all photos functionality
// ✅ Remove individual photos from selection
// ✅ Photo counter accuracy
```

### 3. Delete Functionality Tests
```javascript
// Test Cases:
// ✅ Delete individual photo from activity
// ✅ Delete photo from gallery view
// ✅ Permission-based delete button visibility
// ✅ Confirmation dialog functionality
// ✅ Network error during deletion
// ✅ UI refresh after deletion
```

### 4. Permission Tests
```javascript
// Test Cases:
// ✅ PO role can add/delete photos
// ✅ SYSADMIN role can add/delete photos
// ✅ Regular users cannot delete photos
// ✅ Delete buttons hidden for unauthorized users
// ✅ Backend permission validation
```

### 5. UI/UX Tests
```javascript
// Test Cases:
// ✅ Photo thumbnail generation and display
// ✅ Progress bar accuracy during upload
// ✅ Photo counter updates correctly
// ✅ Responsive photo gallery layout
// ✅ Full-size photo modal functionality
// ✅ Error message display and dismissal
```

## Implementation Checklist

### Backend Setup
- [ ] Implement photo upload endpoint with validation
- [ ] Modify activity info endpoint to merge photos (not replace)
- [ ] Add photo deletion endpoint with permissions
- [ ] Configure Google Cloud Storage or file storage
- [ ] Test dynamic URL generation for different environments

### Frontend Development
- [ ] Create multiple file selection interface
- [ ] Implement sequential photo upload with progress tracking
- [ ] Add global photo state management
- [ ] Create photo thumbnail display with counters
- [ ] Implement individual photo deletion with confirmations
- [ ] Add permission-based UI visibility
- [ ] Create photo gallery modal for viewing all photos

### Testing & Validation
- [ ] Test all upload scenarios (single, multiple, large files, invalid types)
- [ ] Validate photo merging behavior (existing + new photos)
- [ ] Test deletion functionality with proper permissions
- [ ] Verify UI responsiveness and error handling
- [ ] Test network interruption scenarios
- [ ] Validate cross-platform compatibility

### Deployment Considerations
- [ ] Configure storage backend (GCS vs local)
- [ ] Set up proper CORS policies if needed
- [ ] Configure file size limits on server
- [ ] Set up monitoring for upload failures
- [ ] Plan for storage cleanup of deleted photos

## Notes and Best Practices

1. **Photo Merging:** Always merge existing photos with new ones - never replace
2. **Sequential Uploads:** Process files one by one to avoid server overload
3. **State Management:** Use global arrays to maintain photo state across modal sessions
4. **Permission Checks:** Validate permissions both frontend and backend
5. **Error Recovery:** Implement retry mechanisms for network failures
6. **User Feedback:** Provide clear progress indicators and error messages
7. **File Validation:** Validate files before upload to save bandwidth
8. **Storage Strategy:** Plan for both cloud and local storage fallbacks

This implementation guide ensures robust, user-friendly multiple photo functionality that scales well and provides excellent user experience across different platforms and network conditions.
