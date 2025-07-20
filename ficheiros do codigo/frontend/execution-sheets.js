'use strict';

document.addEventListener('DOMContentLoaded', () => {
    // Authentication check
    const token = localStorage.getItem('authToken');
    const authType = localStorage.getItem('authType');
    const username = localStorage.getItem('username');

    if (!token || !username || authType !== 'jwt') {
        window.location.href = 'login.html';
        return;
    }

    const BASE_URL = window.location.pathname.includes("Firstwebapp") ? "/Firstwebapp/rest" : "/rest";

    // User roles and permissions
    let userRoles = [];
    let primaryRole = 'RU';
    let currentSheet = null;
    let notifications = [];
    let currentSheetsData = []; // Store current sheets data globally
    let currentUploadedPhotos = []; // Global array for uploaded photos

    // DOM elements
    const usernameDisplay = document.getElementById('username-display');
    const userInitial = document.getElementById('user-initial');
    const userRoleEl = document.getElementById('user-role');
    const logoutBtn = document.getElementById('logout-btn');
    const refreshBtn = document.getElementById('refresh-btn');
    const notificationsBtn = document.getElementById('notifications-btn');
    const notificationBadge = document.getElementById('notification-badge');

    // Modal elements
    const modalOverlay = document.getElementById('modal-overlay');
    const modalTitle = document.getElementById('modal-title');
    const modalBody = document.getElementById('modal-body');
    const modalClose = document.getElementById('modal-close');

    // Notifications modal
    const notificationsModal = document.getElementById('notifications-modal');
    const notificationsBody = document.getElementById('notifications-body');
    const notificationsClose = document.getElementById('notifications-close');

    // Loading and message elements
    const loading = document.getElementById('loading');
    const message = document.getElementById('message');
    const messageText = document.getElementById('message-text');
    const closeMessage = document.getElementById('close-message');

    // Initialize
    initializeApp();

    async function initializeApp() {
        console.log('Initializing execution sheets app...');
        setupUserInfo();
        await getUserRoles();
        setupRoleBasedInterface();
        setupEventListeners();
        await loadExecutionSheets();
        await loadNotifications();

        // Set up periodic notification checking
        setInterval(loadNotifications, 30000); // Check every 30 seconds
    }

    function setupUserInfo() {
        const displayName = username.includes('@') ? username.split('@')[0] : username;
        usernameDisplay.textContent = displayName;
        userInitial.textContent = displayName.charAt(0).toUpperCase();
    }

    async function getUserRoles() {
        try {
            const payload = JSON.parse(atob(token.split('.')[1]));
            console.log('JWT payload:', payload);
            console.log('Roles from payload:', payload.roles);
            console.log('Role from payload:', payload.role);
            userRoles = payload.roles || (payload.role ? [payload.role] : ['RU']);
            console.log('User roles:', userRoles);
            if (!Array.isArray(userRoles) || userRoles.length === 0) userRoles = ['RU'];
            primaryRole = payload.role || userRoles[0] || 'RU';
            userRoleEl.textContent = primaryRole;
        } catch (error) {
            console.error('Error decoding token:', error);
            userRoles = ['RU'];
            primaryRole = 'RU';
            userRoleEl.textContent = 'RU';
        }
    }

    function setupRoleBasedInterface() {
        const createBtn = document.getElementById('create-sheet-btn');
        const exportBtn = document.getElementById('export-sheet-btn');
        const createAction = document.getElementById('create-action');
        const assignAction = document.getElementById('assign-action');
        const activitiesAction = document.getElementById('activities-action');
        const exportAction = document.getElementById('export-action');
        const parcelsAction = document.getElementById('parcels-action');

        const hide = el => el && (el.style.display = 'none');
        const showEl = el => el && (el.style.display = 'block');

        // Hide all elements initially
        [createBtn,exportBtn,createAction,assignAction,activitiesAction,exportAction,parcelsAction]
            .forEach(hide);

        // Show elements based on roles (using hasRole function to check multiple roles)
        if (canManage()) {
            [createBtn, createAction, assignAction, parcelsAction].forEach(showEl);
        }
        
        if (canExport()) {
            [exportBtn, exportAction].forEach(showEl);
        }
        
        // Only show activities management if user has PO role (and not just PRBO)
        if (canActivity()) {
            showEl(activitiesAction);
        }
    }

    function setupEventListeners() {
        logoutBtn.addEventListener('click', logout);
        refreshBtn.addEventListener('click', () => loadExecutionSheets());
        if (notificationsBtn) notificationsBtn.addEventListener('click', showNotifications);

        modalClose.addEventListener('click', closeModal);
        if (notificationsClose) notificationsClose.addEventListener('click', () => notificationsModal.classList.add('hidden'));
        closeMessage.addEventListener('click', () => message.classList.add('hidden'));

        modalOverlay.addEventListener('click', (e) => {
            if (e.target === modalOverlay) closeModal();
        });

        // Status filter
        const statusFilter = document.getElementById('status-filter');
        if (statusFilter) {
            statusFilter.addEventListener('change', () => loadExecutionSheets());
        }

        // Create sheet button
        const createSheetBtn = document.getElementById('create-sheet-btn');
        if (createSheetBtn) {
            createSheetBtn.addEventListener('click', showCreateModal);
        }

        // Export sheet button
        const exportSheetBtn = document.getElementById('export-sheet-btn');
        if (exportSheetBtn) {
            exportSheetBtn.addEventListener('click', showExportModal);
        }
    }

    // Utility functions
    function hasRole(role) {
        console.log(`Checking role ${role} against userRoles:`, userRoles);
        const result = Array.isArray(userRoles) && userRoles.includes(role);
        console.log(`Role check result for ${role}:`, result);
        return result;
    }

    function show(element) {
        if (element) element.style.display = 'block';
    }

    function hide(element) {
        if (element) element.style.display = 'none';
    }

    const canManage = () => hasRole('SYSADMIN') || hasRole('SYSBO') || hasRole('PRBO');
    const canExport = () => hasRole('SYSADMIN') || hasRole('SYSBO') || hasRole('PRBO') || hasRole('SMBO') || hasRole('SDVBO');
    const canActivity = () => hasRole('SYSADMIN') || hasRole('SYSBO') || hasRole('PO');
    const canAddActivityInfo = () => canActivity(); // PO users can always add activity info, regardless of other roles

    // Função para filtrar parcelas baseada no role do utilizador
    function filterParcelsForUser(parcels) {
        // Apenas PRBO, SMBO e SYSADMIN podem ver todas as parcelas
        if (hasRole('PRBO') || hasRole('SMBO') || hasRole('SYSADMIN')) {
            return parcels; // Mostrar todas as parcelas para estes roles
        }

        // Para todos os outros utilizadores (incluindo POs), aplicar filtro restrito
        const filteredParcels = parcels.filter(parcel => {
            const parcelExec = parcel.parcelExecution;
            const assignedUsername = parcelExec.assignedUsername;
            
            // Mostrar apenas se:
            // 1. Não está atribuída a ninguém (parcela legacy)
            // 2. Está atribuída ao utilizador atual
            const shouldShow = !assignedUsername || 
                             assignedUsername === '' || 
                             assignedUsername === username;
            
            return shouldShow;
        });
        
        return filteredParcels;
    }

    function showLoading() {
        loading.classList.remove('hidden');
    }

    function hideLoading() {
        loading.classList.add('hidden');
    }

    function showMessage(text, type = 'error') {
        messageText.textContent = text;
        message.className = `message ${type}`;
        message.classList.remove('hidden');
        setTimeout(() => message.classList.add('hidden'), 5000);
    }

    function openModal(title, content) {
        modalTitle.textContent = title;
        modalBody.innerHTML = content;
        modalOverlay.classList.remove('hidden');
    }

    function closeModal() {
        modalOverlay.classList.add('hidden');
    }

    function authHeaders() {
        return {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        };
    }

    // Load execution sheets
    async function loadExecutionSheets() {
        console.log('Loading execution sheets...');
        showLoading();
        try {
            const statusFilter = document.getElementById('status-filter');
            const statusValue = statusFilter ? statusFilter.value : '';

            let url = `${BASE_URL}/fe`;
            if (statusValue) {
                url += `?status=${encodeURIComponent(statusValue)}`;
            }

            console.log('Fetching from URL:', url);

            const response = await fetch(url, {
                headers: authHeaders()
            });

            console.log('Response status:', response.status);

            if (response.ok) {
                const sheets = await response.json();
                console.log('Loaded sheets:', sheets);
                renderExecutionSheets(sheets);
            } else {
                const errorText = await response.text();
                console.error('Error response:', errorText);
                showMessage(`Error loading execution sheets: ${errorText}`);
                renderExecutionSheets([]); // Show empty state
            }
        } catch (error) {
            console.error('Error loading execution sheets:', error);
            showMessage('Connection error');
            renderExecutionSheets([]); // Show empty state
        } finally {
            hideLoading();
        }
    }

    function renderExecutionSheets(sheets) {
        // Store sheets data globally for later access
        currentSheetsData = sheets || [];
        
        const grid = document.getElementById('sheets-grid');

        if (!sheets || sheets.length === 0) {
            grid.innerHTML = `
                <div class="empty-state">
                    <div class="icon">📋</div>
                    <h3>No Execution Sheets</h3>
                    <p>Create your first execution sheet to get started</p>
                    ${canManage() ?
                '<button class="action-btn" onclick="showCreateModal()">Create Execution Sheet</button>' :
                ''}
                </div>
            `;
            return;
        }

        // Debug: Check what roles we have
        console.log('Current user roles when rendering sheets:', userRoles);
        console.log('Has PRBO role:', hasRole('PRBO'));
        console.log('Has SDVBO role:', hasRole('SDVBO'));

        const manage = canManage();
        grid.innerHTML = sheets.map(sheet => `
            <div class="sheet-card" onclick="viewSheetDetails('${sheet.id}')">
                <div class="sheet-header">
                    <h3 class="sheet-title">${escapeHtml(sheet.title)}</h3>
                    <span class="sheet-status status-${sheet.state.toLowerCase()}">${sheet.state}</span>
                </div>
                <div class="sheet-info">
                    <p><strong>ID:</strong> ${sheet.id}</p>
                    <p><strong>Work Sheet:</strong> ${sheet.associatedWorkSheetId}</p>
                    <p><strong>User:</strong> ${sheet.associatedUser}</p>
                    <p><strong>Start Date:</strong> ${formatDate(sheet.startDate)}</p>
                    ${sheet.completionDate ? `<p><strong>Completed:</strong> ${formatDate(sheet.completionDate)}</p>` : ''}
                </div>
                <div class="sheet-actions" onclick="event.stopPropagation()">
                    <button class="btn-view" onclick="viewSheetDetails('${sheet.id}')">View</button>
                    ${manage ? `<button class="btn-assign" onclick="showAssignModal('${sheet.id}')">Assign</button>` : ''}
                    ${manage ? `<button class="btn-edit" onclick="showEditModal('${sheet.id}')">Edit</button>` : ''}
                    ${canExport() ? `<button class="btn-export" onclick="exportSheet('${sheet.id}')">Export</button>` : ''}
                    ${manage ? `<button class="btn-delete" onclick="deleteSheet('${sheet.id}')">Delete</button>` : ''}
                </div>
            </div>
        `).join('');
    }

    // View sheet details
    async function viewSheetDetails(sheetId) {
        console.log('Viewing sheet details for:', sheetId);
        showLoading();
        try {
            const response = await fetch(`${BASE_URL}/fe/${sheetId}`, {
                headers: authHeaders()
            });

            if (response.ok) {
                const sheetData = await response.json();
                currentSheet = sheetData;
                renderSheetDetails(sheetData);
                showSheetDetailsView();
            } else {
                showMessage('Error loading sheet details');
            }
        } catch (error) {
            console.error('Error loading sheet details:', error);
            showMessage('Connection error');
        } finally {
            hideLoading();
        }
    }

    function renderSheetDetails(data) {
        const content = document.getElementById('sheet-content');
        const sheet = data.executionSheet;
        const operations = data.operations || [];

        content.innerHTML = `
            <div class="detail-section">
                <h3>Sheet Information</h3>
                <div class="detail-grid">
                    <div class="detail-item">
                        <label>Title</label>
                        <span>${escapeHtml(sheet.title)}</span>
                    </div>
                    <div class="detail-item">
                        <label>Status</label>
                        <span class="sheet-status status-${sheet.state.toLowerCase()}">${sheet.state}</span>
                    </div>
                    <div class="detail-item">
                        <label>Work Sheet ID</label>
                        <span>${sheet.associatedWorkSheetId}</span>
                    </div>
                    <div class="detail-item">
                        <label>Associated User</label>
                        <span>${sheet.associatedUser}</span>
                    </div>
                    <div class="detail-item">
                        <label>Start Date</label>
                        <span>${formatDate(sheet.startDate)}</span>
                    </div>
                    <div class="detail-item">
                        <label>Last Activity</label>
                        <span>${formatDate(sheet.lastActivityDate)}</span>
                    </div>
                    ${sheet.completionDate ? `
                    <div class="detail-item">
                        <label>Completion Date</label>
                        <span>${formatDate(sheet.completionDate)}</span>
                    </div>
                    ` : ''}
                </div>
                ${sheet.observations ? `
                <div class="detail-item" style="margin-top: 20px;">
                    <label>Observations</label>
                    <span>${escapeHtml(sheet.observations)}</span>
                </div>
                ` : ''}
            </div>

            <div class="detail-section">
                <h3>Operations (${operations.length})</h3>
                <div class="operations-grid">
                    ${operations.map(op => renderOperationCard(op)).join('')}
                </div>
            </div>
        `;

        // Initialize photo loading after DOM is updated
        setTimeout(() => {
            initializePhotoLoading();
        }, 100);
    }

    function renderOperationCard(operation) {
        const opExec = operation.operationExecution;
        const parcels = operation.parcels || [];
        const progress = opExec.percentExecuted || 0;

        // Filtrar parcelas para POs - só mostram as que lhes foram atribuídas ou parcelas legacy
        const filteredParcels = filterParcelsForUser(parcels);

        return `
            <div class="operation-card">
                <div class="operation-header">
                    <div class="operation-title">Operation ${opExec.operationId}</div>
                </div>
                <div class="detail-grid" style="margin-top: 15px;">
                    <div class="detail-item">
                        <label>Operation ID</label>
                        <span>${opExec.operationId}</span>
                    </div>
                    <div class="detail-item">
                        <label>Execution ID</label>
                        <span>${opExec.id}</span>
                    </div>
                    <div class="detail-item">
                        <label>Expected Area</label>
                        <span>${opExec.expectedTotalArea || 0} ha</span>
                    </div>
                    <div class="detail-item">
                        <label>Start Date</label>
                        <span>${formatDate(opExec.startDate)}</span>
                    </div>
                    <div class="detail-item">
                        <label>Last Activity</label>
                        <span>${formatDate(opExec.lastActivityDate)}</span>
                    </div>
                </div>
                ${opExec.observations ? `
                <div class="detail-item" style="margin-top: 15px;">
                    <label>Observations</label>
                    <span>${escapeHtml(opExec.observations)}</span>
                </div>
                ` : ''}
                
                <div class="parcels-grid">
                    ${filteredParcels.map(parcel => renderParcelCard(parcel, opExec.id)).join('')}
                    ${filteredParcels.length === 0 && parcels.length > 0 ? `
                        <div class="no-parcels-message">
                            <p style="color: #6c757d; font-style: italic; text-align: center; padding: 20px;">
                                No parcels assigned to you in this operation
                            </p>
                        </div>
                    ` : ''}
                </div>
            </div>
        `;
    }

    function renderParcelCard(parcel, operationId) {
        const parcelExec = parcel.parcelExecution;
        const activities = parcel.activities || [];

        return `
            <div class="parcel-card">
                <div class="parcel-header">
                    <div class="parcel-id">Parcel ${parcelExec.parcelId}</div>
                    <span class="parcel-status status-${parcelExec.status.toLowerCase()}">${parcelExec.status}</span>
                </div>
                <div class="detail-grid">
                    <div class="detail-item">
                        <label>Expected Area</label>
                        <span>${parcelExec.expectedArea || 0} ha</span>
                    </div>
                    <div class="detail-item">
                        <label>Assigned PO</label>
                        ${parcelExec.assignedUsername ? 
                            `<span>${escapeHtml(parcelExec.assignedUsername)}</span>` : 
                            `<span style="color: #6c757d; font-style: italic;">Not assigned (legacy parcel)</span>`
                        }
                    </div>
                </div>
                
                <div class="activities-list">
                    <h5>Activities (${activities.length})</h5>
                    ${activities.map(activity => renderActivityItem(activity, operationId, parcelExec.id)).join('')}
                    ${canActivity() ? `
                                  <div class="activity-actions">
                                      <button class="btn-start" onclick="startActivity('${operationId}', '${parcelExec.id}')">Start Activity</button>
                                  </div>
                                ` : ''}
                </div>
            </div>
        `;
    }

    function renderActivityItem(activity, operationId, parcelExecId) {
        const isRunning = !activity.endTime;
        const canStop = canActivity() && isRunning && activity.operatorId === username;
        const canAddInfo = canAddActivityInfo() && !isRunning;

        return `
            <div class="activity-item">
                <div class="activity-header">
                    <div class="activity-operator">${activity.operatorId}</div>
                    <span class="activity-status ${isRunning ? 'activity-running' : 'activity-completed'}">
                        ${isRunning ? 'Running' : 'Completed'}
                    </span>
                </div>
                <div style="font-size: 11px; color: #6c757d;">
                    <strong>ID:</strong> ${activity.id}<br>
                    Start: ${formatDateTime(activity.startTime)}
                    ${activity.endTime ? `<br>End: ${formatDateTime(activity.endTime)}` : ''}
                </div>
                ${activity.observations ? `
                    <div style="margin-top: 5px; font-size: 11px;">
                        ${escapeHtml(activity.observations)}
                    </div>
                ` : ''}
                ${activity.photoUrls && activity.photoUrls.length > 0 ? `
                    <div class="activity-photos" style="margin-top: 8px;">
                        <div style="font-size: 10px; color: #6c757d; margin-bottom: 4px;">
                            📷 ${activity.photoUrls.length} photo${activity.photoUrls.length > 1 ? 's' : ''}
                            ${canAddInfo ? `<span style="margin-left: 8px; font-size: 9px;">(click × to delete)</span>` : ''}
                        </div>
                        <div class="photo-thumbnails">
                            ${activity.photoUrls.slice(0, 3).map((url, index) => {
                                return `
                                <div class="activity-photo-container" data-photo-index="${index}">
                                    <img src="data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjQwIiBoZWlnaHQ9IjQwIiBmaWxsPSIjRjNGNEY2Ii8+CjxwYXRoIGQ9Ik0yMCAyMkMyMS4xMDQ2IDIyIDIyIDIxLjEwNDYgMjIgMjBDMjIgMTguODk1NCAyMS4xMDQ2IDE4IDIwIDE4QzE4Ljg5NTQgMTggMTggMTguODk1NCAxOCAyMEMxOCAyMS4xMDQ2IDE4Ljg5NTQgMjIgMjAgMjJaIiBmaWxsPSIjOTCA5NyIvPgo8L3N2Zz4K" 
                                         alt="Loading..." class="activity-photo-thumb loading-placeholder" 
                                         data-actual-src="${url}" data-activity-id="${activity.id}"
                                         onclick="viewPhotoModal('${url}')" title="Loading photo...">
                                    <div class="photo-error" style="display: none; padding: 8px; background: #f8f9fa; border: 1px dashed #dc3545; text-align: center; font-size: 10px; color: #dc3545; border-radius: 4px;">
                                        ⚠️ Failed to load<br>
                                        <button onclick="retryPhotoLoad(this)" style="font-size: 9px; padding: 2px 6px; margin-top: 4px; border: 1px solid #dc3545; background: white; color: #dc3545; border-radius: 2px; cursor: pointer;">Retry</button>
                                    </div>
                                    ${canAddInfo ? `
                                        <button class="delete-photo-btn" onclick="deleteActivityPhoto('${activity.id}', '${url}', event)" title="Delete photo">×</button>
                                    ` : ''}
                                </div>
                            `}).join('')}
                            ${activity.photoUrls.length > 3 ? `
                                <div class="photo-more" onclick="viewAllPhotos('${activity.id}', ${JSON.stringify(activity.photoUrls).replace(/"/g, '&quot;')})">
                                    +${activity.photoUrls.length - 3} more
                                </div>
                            ` : ''}
                        </div>
                    </div>
                ` : ''}
                <div class="activity-actions">
                    ${canStop ? `<button class="btn-stop" onclick="stopActivity('${operationId}', '${activity.id}')">Stop</button>` : ''}
                    ${canAddInfo ? `<button class="btn-info" onclick="addActivityInfo('${activity.id}')">Add Info</button>` : ''}
                </div>
            </div>
        `;
    }


    function showSheetDetailsView() {
        document.getElementById('sheets-section').style.display = 'none';
        document.getElementById('activities-section').style.display = 'none';
        document.getElementById('sheet-details').style.display = 'block';
        document.getElementById('page-title').textContent = 'Execution Sheet Details';

        // Show edit button if user has permission
        const editBtn = document.getElementById('edit-sheet-btn');
        if (canManage()) {
            show(editBtn);
        }
    }

    function hideSheetDetails() {
        document.getElementById('sheet-details').style.display = 'none';
        document.getElementById('sheets-section').style.display = 'block';
        document.getElementById('page-title').textContent = 'Execution Sheets';
        currentSheet = null;
    }

    // Create execution sheet
    window.showCreateModal = async function() {
        if (!canManage()) {
            showMessage('Insufficient permissions');
            return;
        }

        // Load available worksheets first
        showLoading();
        try {
            const response = await fetch(`${BASE_URL}/fe/available-worksheets`, {
                headers: authHeaders()
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${await response.text()}`);
            }

            const worksheets = await response.json();
            console.log('Available worksheets received:', worksheets);
            hideLoading();

            if (worksheets.length === 0) {
                showMessage('No worksheets available for creating execution sheets', 'error');
                return;
            }

            const worksheetOptions = worksheets.map(ws => {
                console.log('Processing worksheet:', ws);
                const id = ws.id || 'unknown';
                const title = ws.title || 'Untitled';
                return `<option value="${id}">${escapeHtml(title)} (ID: ${id})</option>`;
            }).join('');

            console.log('Generated options:', worksheetOptions);

            openModal('Create Execution Sheet', `
                <form id="create-sheet-form">
                    <div class="form-group">
                        <label for="sheet-title">Title *</label>
                        <input type="text" id="sheet-title" name="title" required>
                    </div>
                    <div class="form-group">
                        <label for="sheet-description">Description</label>
                        <textarea id="sheet-description" name="description" rows="3"></textarea>
                    </div>
                    <div class="form-group">
                        <label for="worksheet-id">Work Sheet *</label>
                        <select id="worksheet-id" name="associatedWorkSheetId" required>
                            <option value="">Select a work sheet...</option>
                            ${worksheetOptions}
                        </select>
                        <small class="form-hint">Only work sheets without existing execution sheets are shown</small>
                    </div>
                    <div class="form-actions">
                        <button type="button" class="btn-secondary" onclick="closeModal()">Cancel</button>
                        <button type="submit" class="action-btn">Create</button>
                    </div>
                </form>
            `);

            document.getElementById('create-sheet-form').addEventListener('submit', createExecutionSheet);
        } catch (error) {
            hideLoading();
            console.error('Error loading worksheets:', error);
            showMessage('Error loading available worksheets');
        }
    };

    async function createExecutionSheet(e) {
        e.preventDefault();
        const formData = new FormData(e.target);
        const data = {
            title: formData.get('title'),
            description: formData.get('description'),
            associatedWorkSheetId: formData.get('associatedWorkSheetId')
        };

        showLoading();
        closeModal();

        try {
            const response = await fetch(`${BASE_URL}/fe/create`, {
                method: 'POST',
                headers: authHeaders(),
                body: JSON.stringify(data)
            });

            const result = await response.text();
            if (response.ok) {
                showMessage('Execution sheet created successfully!', 'success');
                loadExecutionSheets();
            } else {
                // Handle specific error cases
                let errorMessage = result || 'Error creating execution sheet';
                if (response.status === 409) {
                    errorMessage = 'This work sheet already has an execution sheet associated with it. Please select a different work sheet.';
                } else if (response.status === 404) {
                    errorMessage = 'The selected work sheet was not found. Please refresh and try again.';
                } else if (response.status === 403) {
                    errorMessage = 'You do not have permission to create execution sheets.';
                }
                showMessage(errorMessage, 'error');
            }
        } catch (error) {
            console.error('Error creating execution sheet:', error);
            showMessage('Connection error. Please check your internet connection and try again.', 'error');
        } finally {
            hideLoading();
        }
    }

    // Edit execution sheet
    window.showEditModal = function(sheetId) {
        if (!canManage()) {
            showMessage('Insufficient permissions');
            return;
        }

        // First get the current sheet data
        fetch(`${BASE_URL}/fe/${sheetId}`, { headers: authHeaders() })
            .then(response => response.json())
            .then(data => {
                const sheet = data.executionSheet;

                openModal('Edit Execution Sheet', `
                    <form id="edit-sheet-form">
                        <input type="hidden" name="sheetId" value="${sheetId}">
                        <div class="form-group">
                            <label for="edit-sheet-title">Title *</label>
                            <input type="text" id="edit-sheet-title" name="title" value="${escapeHtml(sheet.title)}" required>
                        </div>
                        <div class="form-group">
                            <label for="edit-sheet-description">Description</label>
                            <textarea id="edit-sheet-description" name="description" rows="3">${escapeHtml(sheet.description || '')}</textarea>
                        </div>
                        <div class="form-group">
                            <label for="edit-sheet-observations">Observations</label>
                            <textarea id="edit-sheet-observations" name="observations" rows="3">${escapeHtml(sheet.observations || '')}</textarea>
                        </div>
                        <div class="form-group">
                            <label for="edit-sheet-state">State</label>
                            <select id="edit-sheet-state" name="state">
                                <option value="PENDING" ${sheet.state === 'PENDING' ? 'selected' : ''}>Pending</option>
                                <option value="IN_PROGRESS" ${sheet.state === 'IN_PROGRESS' ? 'selected' : ''}>In Progress</option>
                                <option value="COMPLETED" ${sheet.state === 'COMPLETED' ? 'selected' : ''}>Completed</option>
                                <option value="CANCELLED" ${sheet.state === 'CANCELLED' ? 'selected' : ''}>Cancelled</option>
                            </select>
                        </div>
                        <div class="form-actions">
                            <button type="button" class="btn-secondary" onclick="closeModal()">Cancel</button>
                            <button type="submit" class="action-btn">Update</button>
                        </div>
                    </form>
                `);

                document.getElementById('edit-sheet-form').addEventListener('submit', updateExecutionSheet);
            })
            .catch(error => {
                console.error('Error loading sheet for edit:', error);
                showMessage('Error loading sheet data');
            });
    };

    async function updateExecutionSheet(e) {
        e.preventDefault();
        const formData = new FormData(e.target);
        const sheetId = formData.get('sheetId');
        const data = {
            title: formData.get('title'),
            description: formData.get('description'),
            observations: formData.get('observations'),
            state: formData.get('state')
        };

        showLoading();
        closeModal();

        try {
            const response = await fetch(`${BASE_URL}/fe/${sheetId}`, {
                method: 'PUT',
                headers: authHeaders(),
                body: JSON.stringify(data)
            });

            const result = await response.text();
            if (response.ok) {
                showMessage('Execution sheet updated successfully!', 'success');
                loadExecutionSheets();
                if (currentSheet && currentSheet.executionSheet.id === sheetId) {
                    viewSheetDetails(sheetId); // Refresh details view
                }
            } else {
                showMessage(result || 'Error updating execution sheet');
            }
        } catch (error) {
            console.error('Error updating execution sheet:', error);
            showMessage('Connection error');
        } finally {
            hideLoading();
        }
    }

    // Delete execution sheet
    window.deleteSheet = async function(sheetId) {
        if (!canManage()) {
            showMessage('Insufficient permissions');
            return;
        }

        if (!confirm('Are you sure you want to delete this execution sheet? This action cannot be undone.')) {
            return;
        }

        showLoading();
        try {
            const response = await fetch(`${BASE_URL}/fe/${sheetId}`, {
                method: 'DELETE',
                headers: authHeaders()
            });

            const result = await response.text();
            if (response.ok) {
                showMessage('Execution sheet deleted successfully!', 'success');
                loadExecutionSheets();
                // If we're viewing this sheet, go back to list
                if (currentSheet && currentSheet.executionSheet.id === sheetId) {
                    hideSheetDetails();
                }
            } else {
                showMessage(result || 'Error deleting execution sheet');
            }
        } catch (error) {
            console.error('Error deleting execution sheet:', error);
            showMessage('Connection error');
        } finally {
            hideLoading();
        }
    };

    // Assign operations
    window.showAssignModal = async function(sheetId = null) {
        if (!canManage()) {
            showMessage('Insufficient permissions');
            return;
        }

        const selectedSheet = sheetId || (currentSheet ? currentSheet.executionSheet.id : '');

        openModal('Assign Operations', `
            <form id="assign-form">
                <div class="form-group">
                    <label for="assign-sheet-id">Execution Sheet ID *</label>
                    <input type="text" id="assign-sheet-id" name="executionSheetId" value="${selectedSheet}" required readonly>
                </div>
                <div class="form-group">
                    <label for="assign-operation-select">Operation *</label>
                    <select id="assign-operation-select" name="operationId" required>
                        <option value="">Loading operations...</option>
                    </select>
                    <small class="form-hint">Select an existing operation from this execution sheet</small>
                </div>
                <div class="form-group">
                    <label for="assign-parcel-select">Parcel *</label>
                    <select id="assign-parcel-select" name="parcelId" required disabled>
                        <option value="">Select an operation first</option>
                    </select>
                    <small class="form-hint">Select an existing parcel or add a new one</small>
                </div>
                <div class="form-group">
                    <label for="assign-username">PO User ID *</label>
                    <input type="text" id="assign-username" name="assignedUsername" required placeholder="User ID of the PO">
                    <small class="form-hint">Enter the exact User ID of the PO to assign this parcel to</small>
                </div>
                <div class="form-group">
                    <label for="assign-area">Expected Area (ha) *</label>
                    <input type="number" id="assign-area" name="area" step="0.01" required>
                </div>
                <div class="form-actions">
                    <button type="button" class="btn-secondary" onclick="closeModal()">Cancel</button>
                    <button type="submit" class="action-btn">Assign</button>
                </div>
            </form>
        `);

        // Setup form event listeners
        setupAssignModalEventListeners();
        
        // Load operations for the selected sheet
        await loadOperationsForAssign(selectedSheet);
    };

    async function assignOperation(e) {
        e.preventDefault();
        const formData = new FormData(e.target);
        const data = {
            executionSheetId: formData.get('executionSheetId'),
            operationId: formData.get('operationId'),
            parcelExecutions: [{
                parcelId: formData.get('parcelId'),
                area: parseFloat(formData.get('area')),
                assignedUsername: formData.get('assignedUsername')
            }]
        };

        showLoading();
        closeModal();

        try {
            const response = await fetch(`${BASE_URL}/operations/assign`, {
                method: 'POST',
                headers: authHeaders(),
                body: JSON.stringify(data)
            });

            const result = await response.text();
            if (response.ok) {
                showMessage('Operation assigned successfully!', 'success');
                if (currentSheet) {
                    viewSheetDetails(currentSheet.executionSheet.id);
                }
                loadExecutionSheets();
            } else {
                showMessage(result || 'Error assigning operation');
            }
        } catch (error) {
            console.error('Error assigning operation:', error);
            showMessage('Connection error');
        } finally {
            hideLoading();
        }
    }

    // Start activity
    window.startActivity = async function(operationId, parcelOperationExecutionId) {
        if (!canActivity()) {
            showMessage('Insufficient permissions');
            return;
        }

        showLoading();
        try {
            const response = await fetch(`${BASE_URL}/operations/${operationId}/start`, {
                method: 'POST',
                headers: authHeaders(),
                body: JSON.stringify({ parcelOperationExecutionId })
            });

            const result = await response.text();
            if (response.ok) {
                showMessage('Activity started successfully!', 'success');
                if (currentSheet) {
                    viewSheetDetails(currentSheet.executionSheet.id);
                }
            } else {
                showMessage(result || 'Error starting activity');
            }
        } catch (error) {
            console.error('Error starting activity:', error);
            showMessage('Connection error');
        } finally {
            hideLoading();
        }
    };

    // Stop activity
    window.stopActivity = async function(operationId, activityId) {
        if (!canActivity()) {
            showMessage('Insufficient permissions');
            return;
        }

        showLoading();
        try {
            const response = await fetch(`${BASE_URL}/operations/${operationId}/stop`, {
                method: 'POST',
                headers: authHeaders(),
                body: JSON.stringify({ activityId })
            });

            const result = await response.text();
            if (response.ok) {
                showMessage('Activity stopped successfully!', 'success');
                if (currentSheet) {
                    viewSheetDetails(currentSheet.executionSheet.id);
                }
            } else {
                showMessage(result || 'Error stopping activity');
            }
        } catch (error) {
            console.error('Error stopping activity:', error);
            showMessage('Connection error');
        } finally {
            hideLoading();
        }
    };

    // Add activity info
    window.addActivityInfo = function(activityId) {
        if (!canAddActivityInfo()) {
            showMessage('Insufficient permissions');
            return;
        }

        // Find the activity to get existing photos
        let existingPhotos = [];
        const activities = getAllActivitiesFromCurrentData();
        const activity = activities.find(act => act.id === activityId);
        if (activity && activity.photoUrls) {
            existingPhotos = activity.photoUrls.map(url => ({
                name: url.split('/').pop() || 'Photo',
                url: url,
                success: true
            }));
        }

    function getAllActivitiesFromCurrentData() {
        const activities = [];
        currentSheetsData.forEach(sheet => {
            if (sheet.operations) {
                sheet.operations.forEach(operation => {
                    if (operation.parcels) {
                        operation.parcels.forEach(parcel => {
                            if (parcel.activities) {
                                parcel.activities.forEach(activity => {
                                    activities.push(activity);
                                });
                            }
                        });
                    }
                });
            }
        });
        return activities;
    }

        openModal('Add Activity Information', `
            <form id="activity-info-form">
                <input type="hidden" name="activityId" value="${activityId}">
                <div class="form-group">
                    <label for="activity-observations">Observations</label>
                    <textarea id="activity-observations" name="observations" rows="3"></textarea>
                </div>
                <div class="form-group">
                    <label for="activity-photos">Photos <span style="font-size: 11px; color: #4f695B; font-weight: 500;">📷 Multiple photos supported</span></label>
                    <div class="file-upload-area" onclick="document.getElementById('photo-input').click()">
                        <div class="upload-text">📷 Click to upload multiple photos</div>
                        <div class="upload-hint">JPG, PNG files up to 10MB each • Hold Ctrl/Cmd to select multiple files • Add more photos anytime</div>
                    </div>
                    <input type="file" id="photo-input" multiple accept="image/jpeg,image/png,image/jpg" style="display: none;">
                    <div id="photo-list" class="photo-preview-container"></div>
                    <div id="photo-upload-progress" class="upload-progress" style="display: none;">
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: 0%"></div>
                        </div>
                        <div class="progress-text">Uploading photos...</div>
                    </div>
                </div>
                <div class="form-actions">
                    <button type="button" class="btn-secondary" onclick="closeModal()">Cancel</button>
                    <button type="submit" class="action-btn" id="save-activity-btn">Save</button>
                </div>
            </form>
        `);

        // Handle file uploads
        setupPhotoUpload(existingPhotos);

        document.getElementById('activity-info-form').addEventListener('submit', saveActivityInfo);
    };

    async function saveActivityInfo(e) {
        e.preventDefault();
        const formData = new FormData(e.target);
        const saveBtn = document.getElementById('save-activity-btn');
        
        saveBtn.disabled = true;
        saveBtn.textContent = 'Saving...';

        try {
            // Get uploaded photo URLs from the global array instead of DOM
            const uploadedPhotos = currentUploadedPhotos.map(photo => photo.url).filter(url => url);

            const data = {
                activityId: formData.get('activityId'),
                observations: formData.get('observations') || '',
                photos: uploadedPhotos
            };

            console.log('Sending activity info:', data);

            showLoading();
            closeModal();

            const response = await fetch(`${BASE_URL}/operations/activity/addinfo`, {
                method: 'POST',
                headers: authHeaders(),
                body: JSON.stringify(data)
            });

            console.log('Response status:', response.status);
            console.log('Response headers:', response.headers);

            if (response.ok) {
                const result = await response.json();
                console.log('Success response:', result);
                showMessage('Activity information saved successfully!', 'success');
                if (currentSheet) {
                    viewSheetDetails(currentSheet.executionSheet.id);
                }
            } else {
                const contentType = response.headers.get('content-type');
                let errorMessage;
                
                try {
                    // Try to read as text first since it's more reliable
                    const responseText = await response.text();
                    
                    if (contentType && contentType.includes('application/json') && responseText.trim().startsWith('{')) {
                        const errorData = JSON.parse(responseText);
                        errorMessage = errorData.message || errorData.error || 'Unknown error';
                    } else {
                        errorMessage = responseText || 'Server error occurred';
                    }
                } catch (e) {
                    errorMessage = `Server returned status ${response.status}`;
                }
                
                console.error('Error response:', response.status, errorMessage);
                showMessage(`Error saving activity information: ${errorMessage}`, 'error');
            }
        } catch (error) {
            console.error('Network error saving activity information:', error);
            showMessage('Connection error: ' + error.message, 'error');
        } finally {
            hideLoading();
            saveBtn.disabled = false;
            saveBtn.textContent = 'Save';
        }
    }

    // Setup photo upload functionality with backend endpoint
    function setupPhotoUpload(existingPhotos = []) {
        const photoInput = document.getElementById('photo-input');
        const photoList = document.getElementById('photo-list');
        const progressContainer = document.getElementById('photo-upload-progress');
        const progressBar = progressContainer.querySelector('.progress-fill');
        const progressText = progressContainer.querySelector('.progress-text');

        // Initialize global photos array with existing photos
        currentUploadedPhotos = [...existingPhotos];
        
        // Update display with existing photos
        updatePhotoListDisplay();
        
        // Update upload text based on existing photos
        const uploadText = document.querySelector('.upload-text');
        if (currentUploadedPhotos.length === 0) {
            uploadText.innerHTML = '📷 Click to upload multiple photos';
        } else {
            uploadText.innerHTML = `📷 Click to add more photos (${currentUploadedPhotos.length} already added)`;
        }

        photoInput.addEventListener('change', async (e) => {
            const files = Array.from(e.target.files);
            if (files.length === 0) return;

            // Update upload area text to show selection count
            const uploadText = document.querySelector('.upload-text');
            const currentCount = currentUploadedPhotos.length;
            const newCount = files.length;
            const totalCount = currentCount + newCount;
            
            if (currentCount === 0) {
                // First time adding photos
                if (newCount === 1) {
                    uploadText.innerHTML = '📷 1 photo selected - Click to add more';
                } else {
                    uploadText.innerHTML = `📷 ${newCount} photos selected - Click to add more`;
                }
            } else {
                // Adding to existing photos
                uploadText.innerHTML = `📷 Adding ${newCount} more photo${newCount > 1 ? 's' : ''} (${totalCount} total)`;
            }

            // Validate files
            const invalidFiles = files.filter(file => {
                const validTypes = ['image/jpeg', 'image/png', 'image/jpg'];
                const maxSize = 10 * 1024 * 1024; // 10MB limit
                return !validTypes.includes(file.type) || file.size > maxSize;
            });

            if (invalidFiles.length > 0) {
                showMessage(`${invalidFiles.length} file(s) are invalid. Please upload JPG/PNG files under 10MB each.`, 'error');
                return;
            }

            progressContainer.style.display = 'block';
            let completed = 0;
            let successfulUploads = 0;

            try {
                progressText.textContent = `Uploading ${files.length} photo${files.length > 1 ? 's' : ''}...`;

                // Process files sequentially to avoid overwhelming the server
                for (const file of files) {
                    try {
                        progressText.textContent = `Uploading ${file.name}...`;
                        
                        // Use FormData to upload via backend endpoint
                        const formData = new FormData();
                        formData.append('file', file);

                        const uploadResponse = await fetch(`${BASE_URL}/photos/upload`, {
                            method: 'POST',
                            headers: {
                                'Authorization': `Bearer ${localStorage.getItem('authToken')}`
                            },
                            body: formData
                        });

                        if (!uploadResponse.ok) {
                            const errorText = await uploadResponse.text();
                            let errorMessage;
                            try {
                                const errorData = JSON.parse(errorText);
                                errorMessage = errorData.error || errorText;
                            } catch (e) {
                                errorMessage = errorText;
                            }
                            throw new Error(`Upload failed: ${errorMessage}`);
                        }

                        const uploadData = await uploadResponse.json();
                        
                        currentUploadedPhotos.push({
                            name: file.name,
                            url: uploadData.photoUrl,
                            success: true
                        });

                        successfulUploads++;

                    } catch (error) {
                        console.error(`Error uploading ${file.name}:`, error);
                        showMessage(`Failed to upload ${file.name}: ${error.message}`, 'error');
                    } finally {
                        completed++;
                        const progress = (completed / files.length) * 100;
                        progressBar.style.width = `${progress}%`;
                    }
                }

                // Update photo list display
                updatePhotoListDisplay();

                // Show completion message
                if (successfulUploads === files.length) {
                    progressText.textContent = `Successfully uploaded ${successfulUploads} photo${successfulUploads !== 1 ? 's' : ''}!`;
                } else if (successfulUploads > 0) {
                    progressText.textContent = `Uploaded ${successfulUploads}/${files.length} photos`;
                } else {
                    progressText.textContent = `No photos were uploaded successfully`;
                }

                setTimeout(() => {
                    progressContainer.style.display = 'none';
                }, 3000);

            } catch (error) {
                console.error('Upload error:', error);
                showMessage(`Upload failed: ${error.message}`, 'error');
                progressContainer.style.display = 'none';
            }

            // Clear the input for future uploads
            photoInput.value = '';
            
            // Reset upload text to reflect current state
            if (currentUploadedPhotos.length === 0) {
                uploadText.innerHTML = '📷 Click to upload multiple photos';
            } else {
                uploadText.innerHTML = `📷 Click to add more photos (${currentUploadedPhotos.length} added)`;
            }
        });

        function resetUploadInterface() {
            const uploadText = document.querySelector('.upload-text');
            if (currentUploadedPhotos.length === 0) {
                uploadText.innerHTML = '📷 Click to upload multiple photos';
            } else {
                uploadText.innerHTML = `📷 Click to add more photos (${currentUploadedPhotos.length} already added)`;
            }
            photoInput.value = '';
            updatePhotoListDisplay();
        }

        function updatePhotoListDisplay() {
            // Add counter header if multiple photos
            let counterHtml = '';
            if (currentUploadedPhotos.length > 1) {
                counterHtml = `
                    <div class="photos-counter">
                        📷 ${currentUploadedPhotos.length} photos selected
                        <button type="button" class="clear-all-photos" onclick="clearAllPhotos()" title="Remove all photos">Clear All</button>
                    </div>
                `;
            }

            photoList.innerHTML = counterHtml + currentUploadedPhotos.map((photo, index) => `
                <div class="photo-item" data-photo-url="${photo.url}" data-photo-index="${index}">
                    <img src="${photo.url}" alt="${photo.name}" class="photo-thumbnail" 
                         onclick="viewPhotoModal('${photo.url}')" title="Click to view full size">
                    <div class="photo-name" title="${photo.name}">${photo.name}</div>
                    <button type="button" class="remove-photo" onclick="removePhoto(this, ${index})" title="Remove photo">×</button>
                </div>
            `).join('');
        }

        // Function to clear all photos
        window.clearAllPhotos = function() {
            currentUploadedPhotos = [];
            updatePhotoListDisplay();
            resetUploadInterface();
        };

        // Remove photo function
        window.removePhoto = function(button, photoIndex) {
            const photoItem = button.closest('.photo-item');
            photoItem.remove();
            currentUploadedPhotos.splice(photoIndex, 1);
            updatePhotoListDisplay();
            
            // Update upload text to reflect new count
            const uploadText = document.querySelector('.upload-text');
            if (currentUploadedPhotos.length === 0) {
                uploadText.innerHTML = '📷 Click to upload multiple photos';
            } else {
                uploadText.innerHTML = `📷 Click to add more photos (${currentUploadedPhotos.length} added)`;
            }
        };
    }

    // Helper function to convert file to base64
    function convertToBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.readAsDataURL(file);
            reader.onload = () => resolve(reader.result);
            reader.onerror = error => reject(error);
        });
    }

    // Export sheet
    window.showExportModal = function() {
        if (!canExport()) {
            showMessage('Insufficient permissions');
            return;
        }

        openModal('Export Execution Sheet', `
            <form id="export-form">
                <div class="form-group">
                    <label for="export-sheet-id">Execution Sheet ID *</label>
                    <input type="text" id="export-sheet-id" name="sheetId" value="${currentSheet ? currentSheet.executionSheet.id : ''}" required>
                </div>
                <div class="form-actions">
                    <button type="button" class="btn-secondary" onclick="closeModal()">Cancel</button>
                    <button type="submit" class="action-btn">Export</button>
                </div>
            </form>
        `);

        document.getElementById('export-form').addEventListener('submit', exportExecutionSheet);
    };

    window.exportSheet = function(sheetId) {
        if (!canExport()) {
            showMessage('Insufficient permissions');
            return;
        }
        exportExecutionSheetById(sheetId);
    };

    async function exportExecutionSheet(e) {
        e.preventDefault();
        const formData = new FormData(e.target);
        const sheetId = formData.get('sheetId');
        closeModal();
        await exportExecutionSheetById(sheetId);
    }

    async function exportExecutionSheetById(sheetId) {
        showLoading();
        try {
            const response = await fetch(`${BASE_URL}/fe/export/${sheetId}`, {
                headers: authHeaders()
            });

            if (response.ok) {
                const data = await response.text();

                // Create and download file
                const blob = new Blob([data], { type: 'application/json' });
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `execution-sheet-${sheetId}.json`;
                document.body.appendChild(a);
                a.click();
                window.URL.revokeObjectURL(url);
                document.body.removeChild(a);

                showMessage('Execution sheet exported successfully!', 'success');
            } else {
                showMessage('Error exporting execution sheet');
            }
        } catch (error) {
            console.error('Error exporting execution sheet:', error);
            showMessage('Connection error');
        } finally {
            hideLoading();
        }
    }

    // Activities view
    window.showActivitiesView = function() {
        if (!canActivity()) {
            showMessage('Insufficient permissions');
            return;
        }

        document.getElementById('sheets-section').style.display = 'none';
        document.getElementById('sheet-details').style.display = 'none';
        document.getElementById('activities-section').style.display = 'block';
        document.getElementById('page-title').textContent = 'Activities Management';

        loadActivitiesSheets();
    };

    function hideActivitiesView() {
        document.getElementById('activities-section').style.display = 'none';
        document.getElementById('sheets-section').style.display = 'block';
        document.getElementById('page-title').textContent = 'Execution Sheets';
    }

    async function loadActivitiesSheets() {
        try {
            const response = await fetch(`${BASE_URL}/fe`, {
                headers: authHeaders()
            });

            if (response.ok) {
                const sheets = await response.json();
                const select = document.getElementById('activity-sheet-filter');
                select.innerHTML = '<option value="">Select Execution Sheet</option>' +
                    sheets.map(sheet => `<option value="${sheet.id}">${escapeHtml(sheet.title)} (${sheet.id})</option>`).join('');

                select.addEventListener('change', (e) => {
                    if (e.target.value) {
                        loadActivitiesForSheet(e.target.value);
                    }
                });
            }
        } catch (error) {
            console.error('Error loading sheets for activities:', error);
        }
    }

    async function loadActivitiesForSheet(sheetId) {
        showLoading();
        try {
            const response = await fetch(`${BASE_URL}/fe/${sheetId}`, {
                headers: authHeaders()
            });

            if (response.ok) {
                const sheetData = await response.json();
                renderActivitiesContent(sheetData);
            } else {
                showMessage('Error loading activities');
            }
        } catch (error) {
            console.error('Error loading activities:', error);
            showMessage('Connection error');
        } finally {
            hideLoading();
        }
    }

    function renderActivitiesContent(data) {
        const content = document.getElementById('activities-content');
        const operations = data.operations || [];

        content.innerHTML = `
            <div class="operations-grid">
                ${operations.map(op => renderOperationCard(op)).join('')}
            </div>
        `;
    }

    // Notifications
    async function loadNotifications() {
        try {
            const response = await fetch(`${BASE_URL}/notify-out/notifications`, {
                headers: authHeaders()
            });

            if (response.ok) {
                notifications = await response.json();
                updateNotificationBadge();
            }
        } catch (error) {
            console.error('Error loading notifications:', error);
        }
    }

    function updateNotificationBadge() {
        if (!notificationBadge) return;

        const unreadCount = notifications.filter(n => !n.read).length;
        if (unreadCount > 0) {
            notificationBadge.textContent = unreadCount;
            notificationBadge.classList.remove('hidden');
        } else {
            notificationBadge.classList.add('hidden');
        }
    }

    function showNotifications() {
        if (!notificationsModal || !notificationsBody) return;

        notificationsBody.innerHTML = notifications.length === 0 ?
            '<p>No notifications</p>' :
            notifications.map(notification => `
                <div class="notification-item ${!notification.read ? 'notification-unread' : ''}">
                    <div class="notification-header">
                        <div class="notification-title">${escapeHtml(notification.title)}</div>
                        <div class="notification-time">${formatDateTime(notification.timestamp)}</div>
                    </div>
                    <div class="notification-message">${escapeHtml(notification.message)}</div>
                </div>
            `).join('');

        notificationsModal.classList.remove('hidden');
    }

    // Utility functions
    function formatDate(timestamp) {
        if (!timestamp) return 'N/A';
        return new Date(timestamp).toLocaleDateString();
    }

    function formatDateTime(timestamp) {
        if (!timestamp) return 'N/A';
        return new Date(timestamp).toLocaleString();
    }

    function escapeHtml(text) {
        if (!text) return '';
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // Logout
    async function logout() {
        showLoading();
        try {
            await fetch(`${BASE_URL}/logout/jwt`, {
                method: 'POST',
                headers: authHeaders()
            });
        } finally {
            localStorage.removeItem('authToken');
            localStorage.removeItem('authType');
            localStorage.removeItem('username');
            window.location.href = 'login.html';
        }
    }

    // Global functions
    window.viewSheetDetails = viewSheetDetails;
    window.hideSheetDetails = hideSheetDetails;
    window.hideActivitiesView = hideActivitiesView;
    window.closeModal = closeModal;

    // Photo loading system with retry mechanism
    let photoLoadQueue = [];
    let isLoadingPhotos = false;

    window.initializePhotoLoading = function() {
        // Find all photo placeholders and queue them for loading
        const placeholders = document.querySelectorAll('.loading-placeholder[data-actual-src]');
        photoLoadQueue = Array.from(placeholders);
        
        console.log(`Found ${photoLoadQueue.length} photos to load`);
        
        if (photoLoadQueue.length > 0 && !isLoadingPhotos) {
            loadPhotosSequentially();
        }
    };

    function loadPhotosSequentially() {
        if (isLoadingPhotos || photoLoadQueue.length === 0) return;
        
        isLoadingPhotos = true;
        console.log('Starting sequential photo loading...');
        
        processNextPhoto();
    }

    async function processNextPhoto() {
        if (photoLoadQueue.length === 0) {
            isLoadingPhotos = false;
            console.log('All photos processed');
            return;
        }

        const placeholder = photoLoadQueue.shift();
        if (!placeholder || !placeholder.dataset.actualSrc) {
            processNextPhoto();
            return;
        }

        const actualUrl = placeholder.dataset.actualSrc;
        const activityId = placeholder.dataset.activityId;
        
        console.log(`Loading photo for activity ${activityId}:`, actualUrl);

        try {
            await loadPhotoWithRetry(placeholder, actualUrl, 3);
        } catch (error) {
            console.error(`Failed to load photo after retries:`, actualUrl, error);
            showPhotoError(placeholder);
        }

        // Small delay between photos to avoid overwhelming the server
        setTimeout(processNextPhoto, 200);
    }

    function loadPhotoWithRetry(imgElement, url, retries = 3) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            
            img.onload = () => {
                // Success - update the placeholder
                imgElement.src = url;
                imgElement.title = 'Click to view full size';
                imgElement.classList.remove('loading-placeholder');
                console.log('✅ Photo loaded successfully:', url);
                resolve();
            };
            
            img.onerror = () => {
                console.warn(`❌ Failed to load photo (${retries} retries left):`, url);
                
                // Test the URL directly to get more info about the error
                fetch(url, { method: 'HEAD' })
                    .then(response => {
                        console.log(`HTTP HEAD test for ${url}:`, {
                            status: response.status,
                            statusText: response.statusText,
                            headers: Object.fromEntries(response.headers.entries())
                        });
                    })
                    .catch(fetchError => {
                        console.error(`HTTP HEAD test failed for ${url}:`, fetchError);
                    });
                
                if (retries > 0) {
                    // Retry with exponential backoff
                    const delay = (4 - retries) * 1000; // 1s, 2s, 3s delays
                    console.log(`Retrying in ${delay}ms...`);
                    setTimeout(() => {
                        loadPhotoWithRetry(imgElement, url, retries - 1)
                            .then(resolve)
                            .catch(reject);
                    }, delay);
                } else {
                    reject(new Error(`Failed to load after all retries: ${url}`));
                }
            };
            
            // Add cache-busting parameter and load
            const cacheBustUrl = url + (url.includes('?') ? '&' : '?') + 't=' + Date.now() + '&retry=' + (3 - retries);
            console.log(`Attempting to load photo (retry ${3-retries}):`, cacheBustUrl);
            img.src = cacheBustUrl;
        });
    }

    function showPhotoError(imgElement) {
        const container = imgElement.closest('.activity-photo-container');
        if (container) {
            imgElement.style.display = 'none';
            const errorDiv = container.querySelector('.photo-error');
            if (errorDiv) {
                errorDiv.style.display = 'block';
            }
        }
    }

    window.retryPhotoLoad = function(button) {
        const container = button.closest('.activity-photo-container');
        const imgElement = container.querySelector('img');
        const errorDiv = container.querySelector('.photo-error');
        
        if (imgElement && imgElement.dataset.actualSrc) {
            // Hide error and show loading
            errorDiv.style.display = 'none';
            imgElement.style.display = 'block';
            imgElement.classList.add('loading-placeholder');
            imgElement.title = 'Retrying...';
            
            // Retry loading
            loadPhotoWithRetry(imgElement, imgElement.dataset.actualSrc, 2)
                .catch(() => showPhotoError(imgElement));
        }
    };

    // Debug function to check photo URLs
    window.debugPhotos = function() {
        const activities = getAllActivitiesFromCurrentData();
        console.log('=== PHOTO DEBUG INFO ===');
        activities.forEach(activity => {
            if (activity.photoUrls && activity.photoUrls.length > 0) {
                console.log(`Activity ${activity.id}:`, {
                    photoCount: activity.photoUrls.length,
                    urls: activity.photoUrls,
                    operator: activity.operatorId
                });
                
                // Test each URL with detailed info
                activity.photoUrls.forEach((url, index) => {
                    console.log(`Testing photo ${index + 1}:`, url);
                    
                    // Test with Image object
                    const img = new Image();
                    img.onload = () => console.log(`✅ Image ${index + 1} accessible:`, url);
                    img.onerror = () => console.error(`❌ Image ${index + 1} failed:`, url);
                    img.src = url;
                    
                    // Test with Fetch (more detailed)
                    fetch(url, { method: 'HEAD' })
                        .then(response => {
                            console.log(`🔍 HTTP HEAD test ${index + 1}:`, {
                                url: url,
                                status: response.status,
                                statusText: response.statusText,
                                ok: response.ok,
                                contentType: response.headers.get('content-type'),
                                contentLength: response.headers.get('content-length'),
                                cacheControl: response.headers.get('cache-control'),
                                lastModified: response.headers.get('last-modified'),
                                etag: response.headers.get('etag')
                            });
                        })
                        .catch(error => {
                            console.error(`🚫 HTTP HEAD test ${index + 1} failed:`, url, error);
                        });
                    
                    // Test with full GET request
                    setTimeout(() => {
                        fetch(url)
                            .then(response => {
                                console.log(`📥 HTTP GET test ${index + 1}:`, {
                                    url: url,
                                    status: response.status,
                                    ok: response.ok,
                                    size: response.headers.get('content-length')
                                });
                                return response.blob();
                            })
                            .then(blob => {
                                console.log(`📦 Blob size ${index + 1}:`, blob.size, 'bytes');
                            })
                            .catch(error => {
                                console.error(`🚫 HTTP GET test ${index + 1} failed:`, url, error);
                            });
                    }, index * 500); // Stagger requests
                });
            }
        });
    };

    // New function to check server health and photo availability
    window.checkPhotoServerHealth = async function() {
        console.log('=== PHOTO SERVER HEALTH CHECK ===');
        
        const activities = getAllActivitiesFromCurrentData();
        let allUrls = [];
        
        activities.forEach(activity => {
            if (activity.photoUrls && activity.photoUrls.length > 0) {
                allUrls = allUrls.concat(activity.photoUrls);
            }
        });
        
        console.log(`Found ${allUrls.length} photo URLs to check`);
        
        if (allUrls.length === 0) {
            console.log('No photos to check');
            return;
        }
        
        // Check each URL with detailed timing
        for (let i = 0; i < allUrls.length; i++) {
            const url = allUrls[i];
            const startTime = performance.now();
            
            try {
                const response = await fetch(url, { 
                    method: 'HEAD',
                    cache: 'no-cache' // Force fresh request
                });
                
                const endTime = performance.now();
                const responseTime = Math.round(endTime - startTime);
                
                console.log(`� Photo ${i+1}/${allUrls.length}:`, {
                    url: url.split('/').pop(), // Just filename for brevity
                    status: response.status,
                    ok: response.ok,
                    responseTime: `${responseTime}ms`,
                    contentType: response.headers.get('content-type'),
                    contentLength: response.headers.get('content-length'),
                    server: response.headers.get('server'),
                    date: response.headers.get('date')
                });
                
            } catch (error) {
                const endTime = performance.now();
                const responseTime = Math.round(endTime - startTime);
                
                console.error(`❌ Photo ${i+1}/${allUrls.length} failed (${responseTime}ms):`, {
                    url: url.split('/').pop(),
                    error: error.message,
                    type: error.name
                });
            }
            
            // Small delay to avoid overwhelming server
            if (i < allUrls.length - 1) {
                await new Promise(resolve => setTimeout(resolve, 100));
            }
        }
        
        console.log('=== HEALTH CHECK COMPLETE ===');
    };

    // Function to test if the issue is with /tmp storage
    window.testTmpStorageIssue = async function() {
        console.log('=== TESTING /tmp STORAGE ISSUE ===');
        
        // Test upload a simple photo and immediately try to access it
        try {
            // Create a simple test image (1x1 pixel PNG)
            const canvas = document.createElement('canvas');
            canvas.width = 1;
            canvas.height = 1;
            const ctx = canvas.getContext('2d');
            ctx.fillStyle = 'red';
            ctx.fillRect(0, 0, 1, 1);
            
            canvas.toBlob(async (blob) => {
                const formData = new FormData();
                formData.append('file', blob, 'test.png');
                
                console.log('Uploading test image...');
                
                try {
                    const uploadResponse = await fetch(`${BASE_URL}/photos/upload`, {
                        method: 'POST',
                        headers: {
                            'Authorization': `Bearer ${localStorage.getItem('authToken')}`
                        },
                        body: formData
                    });
                    
                    if (uploadResponse.ok) {
                        const uploadData = await uploadResponse.json();
                        console.log('✅ Test upload successful:', uploadData.photoUrl);
                        
                        // Immediately try to access the uploaded image
                        const testUrl = uploadData.photoUrl;
                        
                        console.log('Testing immediate access...');
                        const immediateTest = await fetch(testUrl, { method: 'HEAD' });
                        console.log('📊 Immediate access:', immediateTest.status, immediateTest.ok);
                        
                        // Test after 1 second
                        setTimeout(async () => {
                            console.log('Testing access after 1 second...');
                            const delayedTest = await fetch(testUrl, { method: 'HEAD' });
                            console.log('📊 Delayed access (1s):', delayedTest.status, delayedTest.ok);
                        }, 1000);
                        
                        // Test after 5 seconds
                        setTimeout(async () => {
                            console.log('Testing access after 5 seconds...');
                            const delayedTest2 = await fetch(testUrl, { method: 'HEAD' });
                            console.log('📊 Delayed access (5s):', delayedTest2.status, delayedTest2.ok);
                        }, 5000);
                        
                    } else {
                        console.error('❌ Test upload failed:', uploadResponse.status);
                    }
                } catch (error) {
                    console.error('❌ Upload error:', error);
                }
            }, 'image/png');
            
        } catch (error) {
            console.error('❌ Test setup error:', error);
        }
    };

    // New function to check backend photo storage
    window.checkBackendStorage = async function() {
        console.log('=== CHECKING BACKEND STORAGE ===');
        
        try {
            const response = await fetch(`${BASE_URL}/photos/debug/list`, {
                headers: authHeaders()
            });
            
            if (response.ok) {
                const data = await response.json();
                console.log('📁 Backend storage info:', data);
                
                if (data.files && data.files.length > 0) {
                    console.log(`Found ${data.files.length} files in storage:`);
                    data.files.forEach((file, index) => {
                        console.log(`  ${index + 1}. ${file}`);
                    });
                } else {
                    console.log('⚠️ No files found in storage directory');
                }
            } else {
                console.error('❌ Failed to get storage info:', response.status);
            }
        } catch (error) {
            console.error('❌ Error checking backend storage:', error);
        }
    };

    // Activities viewing functions
    window.viewOperationActivities = async function(operationExecutionId) {
        console.log('Viewing activities for operation:', operationExecutionId);
        showLoading();
        
        try {
            const response = await fetch(`${BASE_URL}/operations/${operationExecutionId}/activities`, {
                headers: authHeaders()
            });

            if (response.ok) {
                const activities = await response.json();
                showActivitiesModal('Operation Activities', activities, operationExecutionId);
            } else {
                showMessage('Error loading operation activities');
            }
        } catch (error) {
            console.error('Error loading operation activities:', error);
            showMessage('Connection error');
        } finally {
            hideLoading();
        }
    };

    window.viewParcelActivities = async function(operationExecutionId, parcelOperationExecutionId) {
        console.log('Viewing activities for parcel:', parcelOperationExecutionId);
        showLoading();
        
        try {
            const response = await fetch(`${BASE_URL}/operations/${operationExecutionId}/parcels/${parcelOperationExecutionId}/activities`, {
                headers: authHeaders()
            });

            if (response.ok) {
                const activities = await response.json();
                showActivitiesModal('Parcel Activities', activities, operationExecutionId, parcelOperationExecutionId);
            } else {
                showMessage('Error loading parcel activities');
            }
        } catch (error) {
            console.error('Error loading parcel activities:', error);
            showMessage('Connection error');
        } finally {
            hideLoading();
        }
    };
function showActivitiesModal(title, activities, operationId, parcelId = null) {
    const activitiesHtml = activities.length === 0 ? 
        '<p>No activities found.</p>' :
        activities.map(activity => {
            const activityId = activity.activityId?.string || activity.activityId || 'N/A';
            const operatorId = activity.operatorId?.string || activity.operatorId || 'N/A';
            const parcelIdStr = activity.parcelId?.string || activity.parcelId || 'N/A';
            const gpsTrack = activity.gpsTrack?.string || activity.gpsTrack || '';
            const observations = activity.observations?.string || activity.observations || '';
            const photoUrls = Array.isArray(activity.photoUrls)
                ? activity.photoUrls.map(p => p?.string || p).filter(Boolean)
                : [];

            // ✅ Extract and normalize timestamps
            const startTime = activity.startTime?.string || activity.startTime;
            const endTime = activity.endTime?.string || activity.endTime;

            return `
                <div class="activity-detail-card">
                    <div class="activity-detail-header">
                        <div class="activity-detail-info">
                            <strong>Activity ID:</strong> ${activityId}<br>
                            <strong>Operator:</strong> ${operatorId}<br>
                            <strong>Parcel:</strong> ${parcelIdStr}
                        </div>
                        <span class="activity-status ${!endTime ? 'activity-running' : 'activity-completed'}">
                            ${!endTime ? 'Running' : 'Completed'}
                        </span>
                    </div>
                    <div class="activity-detail-times">
                        <div><strong>Start:</strong> ${formatDateTime(startTime)}</div>
                        ${endTime ? `<div><strong>End:</strong> ${formatDateTime(endTime)}</div>` : ''}
                    </div>
                    ${observations ? `
                    <div class="activity-detail-observations">
                        <strong>Observations:</strong><br>
                        ${escapeHtml(observations)}
                    </div>
                    ` : ''}
                    ${gpsTrack ? `
                    <div class="activity-detail-gps">
                        <strong>GPS Track:</strong> ${gpsTrack}
                    </div>
                    ` : ''}
                    ${photoUrls.length > 0 ? `
                    <div class="activity-detail-photos">
                        <strong>Photos:</strong><br>
                        ${photoUrls.map(url => `<a href="${url}" target="_blank">Photo</a>`).join(', ')}
                    </div>
                    ` : ''}
                    <div class="activity-detail-actions">
                        ${canActivity() && !endTime && operatorId === username ?
                            `<button class="btn-stop" onclick="stopActivityFromModal('${operationId}', '${activityId}')">Stop Activity</button>` : ''}
                        ${canAddActivityInfo() && endTime ?
                            `<button class="btn-info" onclick="addActivityInfoFromModal('${activityId}')">Add Info</button>` : ''}
                    </div>
                </div>
            `;
        }).join('');

    openModal(title, `
        <div class="activities-modal-content">
            ${activitiesHtml}
        </div>
        <div class="form-actions" style="margin-top: 20px;">
            <button class="btn-secondary" onclick="closeModal()">Close</button>
        </div>
    `);
}

window.editOperationExecution = function(operationExecutionId) {
    if (!canManage()) {
        showMessage('Insufficient permissions');
        return;
    }

    openModal('Edit Operation Execution', `
        <form id="edit-operation-execution-form">
            <input type="hidden" name="operationExecutionId" value="${operationExecutionId}">
            <div class="form-group">
                <label for="predictedEndDate">Predicted End Date</label>
                <input type="date" id="predictedEndDate" name="predictedEndDate">
            </div>
            <div class="form-group">
                <label for="estimatedDurationMinutes">Estimated Duration (minutes)</label>
                <input type="number" id="estimatedDurationMinutes" name="estimatedDurationMinutes">
            </div>
            <div class="form-group">
                <label for="expectedTotalArea">Expected Total Area (ha)</label>
                <input type="number" step="0.01" id="expectedTotalArea" name="expectedTotalArea">
            </div>
            <div class="form-group">
                <label for="observations">Observations</label>
                <textarea id="observations" name="observations" rows="3"></textarea>
            </div>
            <div class="form-actions">
                <button type="button" class="btn-secondary" onclick="closeModal()">Cancel</button>
                <button type="submit" class="action-btn">Save</button>
            </div>
        </form>
    `);

    document.getElementById('edit-operation-execution-form').addEventListener('submit', submitEditOperationExecution);
};



async function submitEditOperationExecution(e) {
    e.preventDefault();
    const formData = new FormData(e.target);

    const operationExecutionId = formData.get('operationExecutionId');
    const predictedEndDate = formData.get('predictedEndDate');
    const estimatedDurationMinutes = formData.get('estimatedDurationMinutes');
    const expectedTotalArea = formData.get('expectedTotalArea');
    const observations = formData.get('observations');

    const body = {
        operationExecutionId
    };

    if (predictedEndDate) {
        body.predictedEndDate = new Date(predictedEndDate).toISOString();
    }

    if (estimatedDurationMinutes) {
        body.estimatedDurationMinutes = parseInt(estimatedDurationMinutes, 10);
    }

    if (expectedTotalArea) {
        body.expectedTotalArea = parseFloat(expectedTotalArea);
    }

    if (observations) {
        body.observations = observations;
    }

    showLoading();
    closeModal();

    try {
        const response = await fetch(`${BASE_URL}/operations/edit-operation-execution`, {
            method: 'PATCH',
            headers: authHeaders(),
            body: JSON.stringify(body)
        });

        const result = await response.text();
        if (response.ok) {
            showMessage('Operation updated successfully!', 'success');
            if (currentSheet) {
                viewSheetDetails(currentSheet.executionSheet.id);
            }
        } else {
            showMessage(result || 'Error updating operation');
        }
    } catch (error) {
        console.error('Error updating operation:', error);
        showMessage('Connection error');
    } finally {
        hideLoading();
    }
}

window.showParcelsPanel = function() {
    // Prepare modal content
    const modalTitle = document.getElementById('modal-title');
    const modalBody = document.getElementById('modal-body');
    const modalOverlay = document.getElementById('modal-overlay');

    modalTitle.textContent = "Enter Operation ID";
    modalBody.innerHTML = `
        <div style="display:flex; flex-direction:column; gap:0.5em;">
            <input type="text" id="operation-id-input" placeholder="Operation ID" style="padding:0.5em; border-radius:4px; border:1px solid #ccc;">
            <button id="load-parcels-btn" style="padding:0.5em; border-radius:4px; background:#007bff; color:white; border:none; cursor:pointer;">
                Load Parcels
            </button>
        </div>
    `;

    // Show modal
    modalOverlay.classList.remove('hidden');

    // Attach click handler for the button inside the modal
    document.getElementById('load-parcels-btn').onclick = function() {
        const input = document.getElementById('operation-id-input');
        const operationId = input.value.trim();
        if (!operationId) {
            showMessage("Please enter a valid operation ID.");
            return;
        }

        // Close modal
        modalOverlay.classList.add('hidden');

        // Now load parcels for this ID
        window.loadParcelsForOperation(operationId);
    };
};


// New helper to read the input and call your existing function
window.loadParcelsFromInput = function() {
    const input = document.getElementById('operation-id-input');
    const operationId = input ? input.value.trim() : '';

    if (!operationId) {
        showMessage('Please enter a valid operation ID.');
        return;
    }

    // call the existing method with the entered ID
    window.loadParcelsForOperation(operationId);
};

// The rest of your existing loadParcelsForOperation stays the same
window.loadParcelsForOperation = async function(operationExecutionId) {
    showLoading();
    try {
        const response = await fetch(`${BASE_URL}/operations/${operationExecutionId}/parcels`, {
            headers: authHeaders()
        });

        if (!response.ok) {
            showMessage('Error loading parcels for operation');
            return;
        }

        const parcels = await response.json();
        const container = document.getElementById('operation-parcels-grid');
        const section = document.getElementById('operation-parcels-section');

        if (!parcels || parcels.length === 0) {
            container.innerHTML = '<p>Sem parcelas atribuídas a esta operação.</p>';
        } else {
            container.innerHTML = parcels.map(p => `
                <div class="parcel-list-card">
                    <div class="parcel-list-header">
                        <div class="parcel-list-id">Parcela ${p.parcelId}</div>
                        <div class="parcel-list-status status-${p.status.toLowerCase()}">${p.status}</div>
                    </div>
                    <div><strong>Operação:</strong> ${p.operationId}</div>
                </div>
            `).join('');
        }

        section.style.display = 'block';
        section.scrollIntoView({ behavior: 'smooth' });

    } catch (err) {
        console.error('Erro ao carregar parcelas:', err);
        showMessage('Connection error');
    } finally {
        hideLoading();
    }
};





    // Modal action functions
    window.stopActivityFromModal = async function(operationId, activityId) {
        await stopActivity(operationId, activityId);
        closeModal();
        if (currentSheet) {
            viewSheetDetails(currentSheet.executionSheet.id);
        }
    };

    window.addActivityInfoFromModal = function(activityId) {
        closeModal();
        addActivityInfo(activityId);
    };

    // Helper functions for assign modal
    function setupAssignModalEventListeners() {
        const operationSelect = document.getElementById('assign-operation-select');
        const parcelSelect = document.getElementById('assign-parcel-select');
        
        operationSelect.addEventListener('change', async (e) => {
            const selectedOperationId = e.target.value;
            if (selectedOperationId) {
                parcelSelect.disabled = false;
                parcelSelect.innerHTML = '<option value="">Loading parcels...</option>';
                await loadParcelsForOperation(selectedOperationId);
            } else {
                parcelSelect.disabled = true;
                parcelSelect.innerHTML = '<option value="">Select an operation first</option>';
            }
        });

        document.getElementById('assign-form').addEventListener('submit', assignOperation);
    }

    async function loadOperationsForAssign(sheetId) {
        if (!sheetId) return;

        try {
            const response = await fetch(`${BASE_URL}/fe/${sheetId}`, {
                headers: authHeaders()
            });

            if (response.ok) {
                const sheetData = await response.json();
                const operations = sheetData.operations || [];
                
                const operationSelect = document.getElementById('assign-operation-select');
                operationSelect.innerHTML = '<option value="">Select an operation</option>';
                
                operations.forEach(op => {
                    const opExec = op.operationExecution;
                    const option = document.createElement('option');
                    option.value = opExec.operationId;
                    option.textContent = `${opExec.operationId} (Execution ID: ${opExec.id})`;
                    option.dataset.executionId = opExec.id;
                    operationSelect.appendChild(option);
                });
            } else {
                showMessage('Error loading operations');
            }
        } catch (error) {
            console.error('Error loading operations for assign:', error);
            showMessage('Error loading operations');
        }
    }

    async function loadParcelsForOperation(operationId) {
        try {
            const parcelSelect = document.getElementById('assign-parcel-select');
            parcelSelect.innerHTML = '<option value="">Loading parcels...</option>';

            // Get the worksheetId from the current execution sheet
            const sheetId = document.getElementById('assign-sheet-id').value;
            if (!sheetId) {
                parcelSelect.innerHTML = '<option value="">No execution sheet selected</option>';
                showMessage('No execution sheet selected');
                return;
            }

            // Get the execution sheet data which contains the worksheetId
            const sheetResponse = await fetch(`${BASE_URL}/fe/${sheetId}`, {
                headers: authHeaders()
            });

            if (!sheetResponse.ok) {
                parcelSelect.innerHTML = '<option value="">Error loading execution sheet</option>';
                showMessage('Error loading execution sheet data');
                return;
            }

            const sheetData = await sheetResponse.json();
            const worksheetId = sheetData.executionSheet.associatedWorkSheetId;

            if (!worksheetId) {
                parcelSelect.innerHTML = '<option value="">No worksheet found</option>';
                showMessage('Execution sheet has no associated worksheet');
                return;
            }

            // Now get all parcels that belong to the same worksheet
            const parcelsResponse = await fetch(`${BASE_URL}/fo/${worksheetId}/parcels`, {
                headers: authHeaders()
            });

            if (!parcelsResponse.ok) {
                parcelSelect.innerHTML = '<option value="">Error loading parcels</option>';
                showMessage('Error loading parcels from worksheet');
                return;
            }

            const parcels = await parcelsResponse.json();
            
            // Clear and populate the parcel dropdown
            parcelSelect.innerHTML = '<option value="">Select a parcel</option>';
            
            if (parcels && parcels.length > 0) {
                parcels.forEach(parcel => {
                    const option = document.createElement('option');
                    option.value = parcel.id || parcel.parcelId;
                    option.textContent = `Parcel ${parcel.id || parcel.parcelId} - ${parcel.aigp || 'N/A'} (${parcel.ruralPropertyId || 'N/A'})`;
                    parcelSelect.appendChild(option);
                });
            } else {
                const noParcelOption = document.createElement('option');
                noParcelOption.value = '';
                noParcelOption.textContent = 'No parcels available in this worksheet';
                parcelSelect.appendChild(noParcelOption);
            }

        } catch (error) {
            console.error('Error loading parcels for operation:', error);
            document.getElementById('assign-parcel-select').innerHTML = 
                '<option value="">Error loading parcels</option>';
            showMessage('Error loading parcels');
        }
    }

    // Photo viewing functions
    window.viewPhotoModal = function(photoUrl) {
        // Add cache-busting and error handling
        const cacheBustUrl = photoUrl + (photoUrl.includes('?') ? '&' : '?') + 't=' + Date.now();
        
        openModal('Photo View', `
            <div class="photo-viewer">
                <img src="${cacheBustUrl}" alt="Activity photo" 
                     style="max-width: 100%; max-height: 80vh; border-radius: 8px;"
                     onerror="this.onerror=null; this.src='${photoUrl}'; this.style.border='2px solid red';"
                     onload="console.log('Photo loaded successfully:', '${photoUrl}');">
                <div style="margin-top: 10px; font-size: 12px; color: #666; word-break: break-all;">
                    URL: ${photoUrl}
                </div>
            </div>
        `);
    };

    // Delete individual photo from activity
    window.deleteActivityPhoto = async function(activityId, photoUrl, event) {
        // Stop event propagation to prevent triggering photo view
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }

        if (!canAddActivityInfo()) {
            showMessage('Insufficient permissions to delete photos', 'error');
            return;
        }

        if (!confirm('Are you sure you want to delete this photo? This action cannot be undone.')) {
            return;
        }

        try {
            showLoading();

            // Send request to backend to remove this specific photo
            const response = await fetch(`${BASE_URL}/operations/activity/deletephoto`, {
                method: 'POST',
                headers: authHeaders(),
                body: JSON.stringify({
                    activityId: activityId,
                    photoUrl: photoUrl
                })
            });

            if (response.ok) {
                showMessage('Photo deleted successfully!', 'success');
                // Refresh the current view to show updated photos
                if (currentSheet) {
                    viewSheetDetails(currentSheet.executionSheet.id);
                }
            } else {
                const errorText = await response.text();
                showMessage(`Error deleting photo: ${errorText}`, 'error');
            }
        } catch (error) {
            console.error('Error deleting photo:', error);
            showMessage('Connection error while deleting photo', 'error');
        } finally {
            hideLoading();
        }
    };

    window.viewAllPhotos = function(activityId, photoUrls) {
        const canDelete = canAddActivityInfo(); // Check if user can delete photos
        
        // Add debug information
        console.log('ViewAllPhotos called with:', { activityId, photoUrls, photoCount: photoUrls.length });
        
        const photosHtml = photoUrls.map((url, index) => {
            return `
            <div class="photo-gallery-item">
                <div class="activity-photo-container">
                    <img src="data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iODAiIGhlaWdodD0iODAiIHZpZXdCb3g9IjAgMCA4MCA4MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjgwIiBoZWlnaHQ9IjgwIiBmaWxsPSIjRjNGNEY2Ii8+CjxwYXRoIGQ9Ik00MCA0NEMyMS4xMDQ2IDQ0IDQ0IDQxLjEwNDYgNDQgNDBDNDQgMzguODk1NCA0MS4xMDQ2IDM2IDQwIDM2QzM4Ljg5NTQgMzYgMzYgMzguODk1NCAzNiA0MEMzNiA0MS4xMDQ2IDM4Ljg5NTQgNDQgNDAgNDRaIiBmaWxsPSIjOUNBM0FGIi8+Cjwvc3ZnPgo=" 
                         alt="Loading full size..." class="gallery-photo loading-placeholder-gallery" 
                         data-actual-src="${url}" data-photo-index="${index}"
                         onclick="viewPhotoModal('${url}')" title="Loading photo ${index + 1}...">
                    ${canDelete ? `
                        <button class="delete-photo-btn gallery-delete-btn" onclick="deleteActivityPhoto('${activityId}', '${url}', event)" title="Delete photo">×</button>
                    ` : ''}
                </div>
                <div class="photo-error-gallery" style="display: none; padding: 8px; background: #f8f9fa; border: 1px dashed #dc3545; text-align: center; font-size: 10px; color: #dc3545; border-radius: 4px; margin-top: 4px;">
                    ⚠️ Failed to load photo ${index + 1}<br>
                    <button onclick="retryGalleryPhoto(this, '${url}')" style="font-size: 9px; padding: 2px 6px; margin-top: 4px; border: 1px solid #dc3545; background: white; color: #dc3545; border-radius: 2px; cursor: pointer;">Retry</button>
                </div>
                <div style="font-size: 10px; color: #666; margin-top: 4px; word-break: break-all;">
                    Photo ${index + 1}: ${url.split('/').pop()}
                </div>
            </div>
        `}).join('');

        openModal('All Photos', `
            <div class="photo-gallery">
                <div style="margin-bottom: 15px; font-size: 12px; color: #666;">
                    Showing ${photoUrls.length} photo${photoUrls.length !== 1 ? 's' : ''} for activity ${activityId}
                    <button onclick="retryAllGalleryPhotos()" style="margin-left: 10px; font-size: 10px; padding: 2px 6px; border: 1px solid #007bff; background: white; color: #007bff; border-radius: 2px; cursor: pointer;">Retry All</button>
                </div>
                ${photosHtml}
            </div>
            ${canDelete ? `<p style="text-align: center; margin-top: 15px; font-size: 12px; color: #6c757d;">Click × on any photo to delete it</p>` : ''}
        `);

        // Load gallery photos after modal is shown
        setTimeout(() => {
            loadGalleryPhotos();
        }, 100);
    };

    window.retryGalleryPhoto = function(button, url) {
        const container = button.closest('.photo-gallery-item');
        const imgElement = container.querySelector('img');
        const errorDiv = container.querySelector('.photo-error-gallery');
        
        errorDiv.style.display = 'none';
        imgElement.style.display = 'block';
        imgElement.classList.add('loading-placeholder-gallery');
        
        loadPhotoWithRetry(imgElement, url, 2)
            .catch(() => {
                imgElement.style.display = 'none';
                errorDiv.style.display = 'block';
            });
    };

    window.retryAllGalleryPhotos = function() {
        const placeholders = document.querySelectorAll('.loading-placeholder-gallery[data-actual-src]');
        placeholders.forEach(img => {
            if (img.dataset.actualSrc) {
                loadPhotoWithRetry(img, img.dataset.actualSrc, 2)
                    .catch(() => {
                        const container = img.closest('.photo-gallery-item');
                        const errorDiv = container.querySelector('.photo-error-gallery');
                        img.style.display = 'none';
                        if (errorDiv) errorDiv.style.display = 'block';
                    });
            }
        });
    };

    function loadGalleryPhotos() {
        const placeholders = document.querySelectorAll('.loading-placeholder-gallery[data-actual-src]');
        
        placeholders.forEach((img, index) => {
            // Stagger the loading to avoid overwhelming the server
            setTimeout(() => {
                const url = img.dataset.actualSrc;
                loadPhotoWithRetry(img, url, 3)
                    .catch(() => {
                        const container = img.closest('.photo-gallery-item');
                        const errorDiv = container.querySelector('.photo-error-gallery');
                        img.style.display = 'none';
                        if (errorDiv) errorDiv.style.display = 'block';
                    });
            }, index * 300); // 300ms delay between each photo
        });
    }
});