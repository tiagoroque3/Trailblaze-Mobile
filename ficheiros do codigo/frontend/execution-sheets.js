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
            primaryRole = userRoles[0] || 'RU';
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

        [createBtn,exportBtn,createAction,assignAction,activitiesAction,exportAction,parcelsAction]
            .forEach(hide);

        switch (primaryRole) {
            case 'SYSADMIN':
            case 'SYSBO':
                [createBtn,createAction,assignAction,parcelsAction,exportBtn,exportAction,activitiesAction]
                    .forEach(showEl);
                break;
            case 'SMBO':
                [exportBtn,exportAction].forEach(showEl);
                break;
            case 'PRBO':
                [createBtn,createAction,assignAction,parcelsAction,exportBtn,exportAction,activitiesAction]
                    .forEach(showEl);
                break;
            case 'PO':
                showEl(activitiesAction);
                break;
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

    const canManage = () => ['SYSADMIN','SYSBO','PRBO'].includes(primaryRole);
    const canExport = () => ['SYSADMIN','SYSBO','PRBO','SMBO','SDVBO'].includes(primaryRole);
    const canActivity = () => ['SYSADMIN','SYSBO','PRBO','PO'].includes(primaryRole);

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
    }

    function renderOperationCard(operation) {
        const opExec = operation.operationExecution;
        const parcels = operation.parcels || [];
        const progress = opExec.percentExecuted || 0;

        return `
            <div class="operation-card">
                <div class="operation-header">
                    <div class="operation-title">Operation ${opExec.operationId}</div>
                    <div class="operation-progress">${progress.toFixed(1)}% Complete</div>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: ${progress}%"></div>
                </div>
                <div class="operation-actions" style="margin: 10px 0; text-align: right;">
                    <button class="btn-view" onclick="viewOperationActivities('${opExec.id}')" style="margin-right: 5px;">View Activities</button>
                    ${canManage() ? `<button class="btn-edit" onclick="editOperationExecution('${opExec.id}')">Edit</button>` : ''}
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
                        <label>Executed Area</label>
                        <span>${opExec.totalExecutedArea || 0} ha</span>
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
                    ${parcels.map(parcel => renderParcelCard(parcel, opExec.id)).join('')}
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
                        <label>Executed Area</label>
                        <span>${parcelExec.executedArea || 0} ha</span>
                    </div>
                </div>
                
                <div class="parcel-actions" style="margin: 10px 0; text-align: center;">
                    <button class="btn-view" onclick="viewParcelActivities('${operationId}', '${parcelExec.id}')" style="font-size: 12px; padding: 4px 8px;">View Parcel Activities</button>
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
    const canAddInfo = canActivity() && !isRunning;

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

    // Assign operations (enhanced for PRBO users)
    window.showAssignModal = async function(sheetId = null) {
        if (!canManage()) {
            showMessage('Insufficient permissions - only PRBO users can assign parcels to operations');
            return;
        }

        const selectedSheet = sheetId || (currentSheet ? currentSheet.executionSheet.id : '');

        openModal('Assign Parcels to Operations', `
            <form id="assign-form">
                <div class="form-group">
                    <label for="assign-sheet-id">Execution Sheet ID *</label>
                    <input type="text" id="assign-sheet-id" name="executionSheetId" value="${selectedSheet}" required readonly>
                    <small class="form-hint">The execution sheet where the operation will be assigned</small>
                </div>
                <div class="form-group">
                    <label for="assign-operation-select">Operation *</label>
                    <select id="assign-operation-select" name="operationId" required>
                        <option value="">Loading operations...</option>
                    </select>
                    <small class="form-hint">Select the operation that will be performed on the parcel</small>
                </div>
                <div class="form-group">
                    <label for="assign-parcel-select">Parcel *</label>
                    <select id="assign-parcel-select" name="parcelId" required disabled>
                        <option value="">Select an operation first</option>
                    </select>
                    <small class="form-hint">Select a parcel from the associated worksheet</small>
                </div>
                <div class="form-group">
                    <label for="assign-area">Expected Area (ha) *</label>
                    <input type="number" id="assign-area" name="area" step="0.01" min="0" required>
                    <small class="form-hint">Expected area to be worked on this parcel</small>
                </div>
                <div class="form-group">
                    <label for="assign-notes">Assignment Notes</label>
                    <textarea id="assign-notes" name="notes" rows="3" placeholder="Optional notes about this assignment..."></textarea>
                    <small class="form-hint">Optional notes or special instructions for this assignment</small>
                </div>
                <div class="form-actions">
                    <button type="button" class="btn-secondary" onclick="closeModal()">Cancel</button>
                    <button type="submit" class="action-btn">
                        <span class="btn-text">Assign Parcel</span>
                        <span class="btn-loading" style="display: none;">Assigning...</span>
                    </button>
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
        
        // Show loading state on button
        const submitBtn = e.target.querySelector('button[type="submit"]');
        const btnText = submitBtn.querySelector('.btn-text');
        const btnLoading = submitBtn.querySelector('.btn-loading');
        
        btnText.style.display = 'none';
        btnLoading.style.display = 'inline';
        submitBtn.disabled = true;

        const data = {
            executionSheetId: formData.get('executionSheetId'),
            operationId: formData.get('operationId'),
            parcelExecutions: [{
                parcelId: formData.get('parcelId'),
                area: parseFloat(formData.get('area'))
            }],
            expectedTotalArea: parseFloat(formData.get('area')),
            notes: formData.get('notes') || ''
        };

        // Validation
        if (!data.operationId) {
            showMessage('Please select an operation', 'error');
            btnText.style.display = 'inline';
            btnLoading.style.display = 'none';
            submitBtn.disabled = false;
            return;
        }

        if (!data.parcelExecutions[0].parcelId) {
            showMessage('Please select a parcel', 'error');
            btnText.style.display = 'inline';
            btnLoading.style.display = 'none';
            submitBtn.disabled = false;
            return;
        }

        if (!data.parcelExecutions[0].area || data.parcelExecutions[0].area <= 0) {
            showMessage('Please enter a valid area greater than 0', 'error');
            btnText.style.display = 'inline';
            btnLoading.style.display = 'none';
            submitBtn.disabled = false;
            return;
        }

        showLoading();
        closeModal();

        try {
            console.log('Sending assign request:', data);
            const response = await fetch(`${BASE_URL}/operations/assign`, {
                method: 'POST',
                headers: authHeaders(),
                body: JSON.stringify(data)
            });

            const result = await response.text();
            
            if (response.ok) {
                showMessage(`Parcel ${data.parcelExecutions[0].parcelId} successfully assigned to operation ${data.operationId}!`, 'success');
                
                // Refresh the current view
                if (currentSheet) {
                    await viewSheetDetails(currentSheet.executionSheet.id);
                }
                await loadExecutionSheets();
                
            } else {
                let errorMessage = 'Error assigning parcel to operation';
                try {
                    const errorData = JSON.parse(result);
                    errorMessage = errorData.message || errorData.error || result;
                } catch {
                    errorMessage = result || errorMessage;
                }
                console.error('Assignment error:', errorMessage);
                showMessage(errorMessage, 'error');
            }
        } catch (error) {
            console.error('Error assigning operation:', error);
            showMessage('Connection error - please check your network and try again', 'error');
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
        if (!canActivity()) {
            showMessage('Insufficient permissions');
            return;
        }

        openModal('Add Activity Information', `
            <form id="activity-info-form">
                <input type="hidden" name="activityId" value="${activityId}">
                <div class="form-group">
                    <label for="activity-observations">Observations</label>
                    <textarea id="activity-observations" name="observations" rows="3"></textarea>
                </div>
                <div class="form-group">
                    <label for="activity-photos">Photos</label>
                    <div class="file-upload-area" onclick="document.getElementById('photo-input').click()">
                        <div class="upload-text">Click to upload photos</div>
                        <div class="upload-hint">JPG, PNG files up to 10MB each</div>
                    </div>
                    <input type="file" id="photo-input" multiple accept="image/*" style="display: none;">
                    <div id="photo-list"></div>
                </div>
                <div class="form-group">
                    <label for="activity-gps">GPS Track</label>
                    <div class="file-upload-area" onclick="document.getElementById('gps-input').click()">
                        <div class="upload-text">Click to upload GPS track</div>
                        <div class="upload-hint">GPX files</div>
                    </div>
                    <input type="file" id="gps-input" accept=".gpx" style="display: none;">
                    <div id="gps-file"></div>
                </div>
                <div class="form-actions">
                    <button type="button" class="btn-secondary" onclick="closeModal()">Cancel</button>
                    <button type="submit" class="action-btn">Save</button>
                </div>
            </form>
        `);

        // Handle file uploads
        const photoInput = document.getElementById('photo-input');
        const gpsInput = document.getElementById('gps-input');
        const photoList = document.getElementById('photo-list');
        const gpsFile = document.getElementById('gps-file');

        photoInput.addEventListener('change', (e) => {
            const files = Array.from(e.target.files);
            photoList.innerHTML = files.map(f => `<div>${f.name}</div>`).join('');
        });

        gpsInput.addEventListener('change', (e) => {
            const file = e.target.files[0];
            gpsFile.innerHTML = file ? `<div>${file.name}</div>` : '';
        });

        document.getElementById('activity-info-form').addEventListener('submit', saveActivityInfo);
    };

    async function saveActivityInfo(e) {
        e.preventDefault();
        const formData = new FormData(e.target);

        // For now, we'll just save the observations
        // In a real implementation, you'd upload files to a storage service first
        const data = {
            activityId: formData.get('activityId'),
            observations: formData.get('observations'),
            photos: [], // Would contain uploaded photo URLs
            gpsTracks: [] // Would contain uploaded GPS track URLs
        };

        showLoading();
        closeModal();

        try {
            const response = await fetch(`${BASE_URL}/operations/activity/addinfo`, {
                method: 'POST',
                headers: authHeaders(),
                body: JSON.stringify(data)
            });

            const result = await response.text();
            if (response.ok) {
                showMessage('Activity information saved successfully!', 'success');
                if (currentSheet) {
                    viewSheetDetails(currentSheet.executionSheet.id);
                }
            } else {
                showMessage(result || 'Error saving activity information');
            }
        } catch (error) {
            console.error('Error saving activity information:', error);
            showMessage('Connection error');
        } finally {
            hideLoading();
        }
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
                        ${canActivity() && endTime ?
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
            showMessage('Erro ao carregar parcelas da operação');
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
        showMessage('Erro de ligação');
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
        if (!sheetId) {
            console.warn('No sheet ID provided for loading operations');
            return;
        }

        const operationSelect = document.getElementById('assign-operation-select');
        
        try {
            operationSelect.innerHTML = '<option value="">Loading operations...</option>';
            operationSelect.disabled = true;

            const response = await fetch(`${BASE_URL}/fe/${sheetId}`, {
                headers: authHeaders()
            });

            if (response.ok) {
                const sheetData = await response.json();
                const operations = sheetData.operations || [];
                
                operationSelect.innerHTML = '<option value="">Select an operation</option>';
                
                if (operations.length === 0) {
                    const noOpsOption = document.createElement('option');
                    noOpsOption.value = '';
                    noOpsOption.textContent = 'No operations available in this execution sheet';
                    noOpsOption.disabled = true;
                    operationSelect.appendChild(noOpsOption);
                } else {
                    operations.forEach(op => {
                        const opExec = op.operationExecution;
                        const option = document.createElement('option');
                        option.value = opExec.operationId;
                        option.textContent = `Operation ${opExec.operationId} (${Math.round(opExec.percentExecuted || 0)}% complete)`;
                        option.dataset.executionId = opExec.id;
                        option.dataset.expectedArea = opExec.expectedTotalArea || 0;
                        operationSelect.appendChild(option);
                    });
                }
                
                operationSelect.disabled = false;
            } else {
                operationSelect.innerHTML = '<option value="">Error loading operations</option>';
                const errorText = await response.text();
                console.error('Error loading operations:', errorText);
                showMessage('Error loading operations for this execution sheet', 'error');
            }
        } catch (error) {
            console.error('Error loading operations for assign:', error);
            operationSelect.innerHTML = '<option value="">Connection error</option>';
            showMessage('Network error while loading operations', 'error');
        }
    }

    async function loadParcelsForOperation(operationId) {
        const parcelSelect = document.getElementById('assign-parcel-select');
        
        if (!operationId) {
            parcelSelect.innerHTML = '<option value="">Select an operation first</option>';
            parcelSelect.disabled = true;
            return;
        }

        try {
            parcelSelect.innerHTML = '<option value="">Loading parcels...</option>';
            parcelSelect.disabled = true;

            // Get the worksheetId from the current execution sheet
            const sheetId = document.getElementById('assign-sheet-id').value;
            if (!sheetId) {
                parcelSelect.innerHTML = '<option value="">No execution sheet selected</option>';
                showMessage('No execution sheet selected', 'error');
                return;
            }

            // Get the execution sheet data which contains the worksheetId
            const sheetResponse = await fetch(`${BASE_URL}/fe/${sheetId}`, {
                headers: authHeaders()
            });

            if (!sheetResponse.ok) {
                parcelSelect.innerHTML = '<option value="">Error loading execution sheet</option>';
                showMessage('Error loading execution sheet data', 'error');
                return;
            }

            const sheetData = await sheetResponse.json();
            const worksheetId = sheetData.executionSheet.associatedWorkSheetId;

            if (!worksheetId) {
                parcelSelect.innerHTML = '<option value="">No worksheet found</option>';
                showMessage('Execution sheet has no associated worksheet', 'error');
                return;
            }

            // Now get all parcels that belong to the same worksheet
            const parcelsResponse = await fetch(`${BASE_URL}/fo/${worksheetId}/parcels`, {
                headers: authHeaders()
            });

            if (!parcelsResponse.ok) {
                parcelSelect.innerHTML = '<option value="">Error loading parcels</option>';
                const errorText = await parcelsResponse.text();
                console.error('Error loading parcels:', errorText);
                showMessage('Error loading parcels from worksheet', 'error');
                return;
            }

            const parcels = await parcelsResponse.json();
            
            // Clear and populate the parcel dropdown
            parcelSelect.innerHTML = '<option value="">Select a parcel</option>';
            
            if (parcels && parcels.length > 0) {
                // Filter out parcels that are already assigned to this operation
                const assignedParcels = await getAssignedParcelsForOperation(operationId);
                const availableParcels = parcels.filter(parcel => 
                    !assignedParcels.includes(String(parcel.id || parcel.parcelId))
                );
                
                if (availableParcels.length === 0) {
                    const noParcelsOption = document.createElement('option');
                    noParcelsOption.value = '';
                    noParcelsOption.textContent = 'All parcels in this worksheet are already assigned to this operation';
                    noParcelsOption.disabled = true;
                    parcelSelect.appendChild(noParcelsOption);
                } else {
                    availableParcels.forEach(parcel => {
                        const option = document.createElement('option');
                        option.value = parcel.id || parcel.parcelId;
                        option.textContent = `Parcel ${parcel.id || parcel.parcelId} - ${parcel.aigp || 'N/A'} (${parcel.ruralPropertyId || 'N/A'})`;
                        option.dataset.area = parcel.area || 0;
                        parcelSelect.appendChild(option);
                    });
                    
                    // Auto-fill area when parcel is selected
                    parcelSelect.addEventListener('change', function() {
                        const selectedOption = this.options[this.selectedIndex];
                        const areaInput = document.getElementById('assign-area');
                        if (selectedOption.dataset.area && !areaInput.value) {
                            areaInput.value = selectedOption.dataset.area;
                        }
                    });
                }
                
            } else {
                const noParcelOption = document.createElement('option');
                noParcelOption.value = '';
                noParcelOption.textContent = 'No parcels available in this worksheet';
                noParcelOption.disabled = true;
                parcelSelect.appendChild(noParcelOption);
            }

            parcelSelect.disabled = false;

        } catch (error) {
            console.error('Error loading parcels for operation:', error);
            parcelSelect.innerHTML = '<option value="">Error loading parcels</option>';
            showMessage('Error loading parcels', 'error');
        }
    }
    
    // Helper function to get parcels already assigned to an operation
    async function getAssignedParcelsForOperation(operationId) {
        try {
            // This would need to be implemented in the backend if not already available
            // For now, return empty array
            return [];
        } catch (error) {
            console.error('Error getting assigned parcels:', error);
            return [];
        }
    }
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
});