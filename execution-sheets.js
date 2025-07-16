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
            userRoleEl.textContent = userRoles[0] || 'RU';
            console.log('User roles:', userRoles);
        } catch (error) {
            console.error('Error decoding token:', error);
            userRoles = ['RU'];
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

        console.log('Setting up interface for roles:', userRoles);

        // Show/hide elements based on roles
        if (hasRole('PRBO') || hasRole('SDVBO')) {
            show(createBtn);
            show(createAction);
            show(assignAction);
            show(parcelsAction);
        }

        if (hasRole('SDVBO')) {
            show(exportBtn);
            show(exportAction);
        }

        if (hasRole('PO')) {
            show(activitiesAction);
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
                    ${hasRole('PRBO') || hasRole('SDVBO') ?
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
        
        // Fallback check - if user is not RU, show management buttons
        const canManage = hasRole('PRBO') || hasRole('SDVBO') || 
                         (userRoles.length > 0 && !userRoles.includes('RU') && userRoles[0] !== 'RU');
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
                    ${canManage ? `<button class="btn-assign" onclick="showAssignModal('${sheet.id}')">Assign</button>` : ''}
                    ${canManage ? `<button class="btn-edit" onclick="showEditModal('${sheet.id}')">Edit</button>` : ''}
                    ${hasRole('SDVBO') ? `<button class="btn-export" onclick="exportSheet('${sheet.id}')">Export</button>` : ''}
                    ${canManage ? `<button class="btn-delete" onclick="deleteSheet('${sheet.id}')">Delete</button>` : ''}
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
                    ${hasRole('PRBO') || hasRole('SDVBO') ? `<button class="btn-edit" onclick="editOperationExecution('${opExec.id}')">Edit</button>` : ''}
                </div>
                <div class="detail-grid" style="margin-top: 15px;">
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
                    ${hasRole('PO') ? `
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
    const canStop = hasRole('PO') && isRunning && activity.operatorId === username;
    const canAddInfo = hasRole('PO') && !isRunning;

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
        if (hasRole('PRBO') || hasRole('SDVBO')) {
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
    window.showCreateModal = function() {
        if (!hasRole('PRBO') && !hasRole('SDVBO')) {
            showMessage('Insufficient permissions');
            return;
        }

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
                    <label for="worksheet-id">Work Sheet ID *</label>
                    <input type="text" id="worksheet-id" name="associatedWorkSheetId" required>
                </div>
                <div class="form-actions">
                    <button type="button" class="btn-secondary" onclick="closeModal()">Cancel</button>
                    <button type="submit" class="action-btn">Create</button>
                </div>
            </form>
        `);

        document.getElementById('create-sheet-form').addEventListener('submit', createExecutionSheet);
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
                showMessage(result || 'Error creating execution sheet');
            }
        } catch (error) {
            console.error('Error creating execution sheet:', error);
            showMessage('Connection error');
        } finally {
            hideLoading();
        }
    }

    // Edit execution sheet
    window.showEditModal = function(sheetId) {
        if (!hasRole('PRBO') && !hasRole('SDVBO')) {
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
        if (!hasRole('PRBO') && !hasRole('SDVBO')) {
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
    window.showAssignModal = function(sheetId = null) {
        if (!hasRole('PRBO') && !hasRole('SDVBO')) {
            showMessage('Insufficient permissions');
            return;
        }

        const selectedSheet = sheetId || (currentSheet ? currentSheet.executionSheet.id : '');

        openModal('Assign Operations', `
            <form id="assign-form">
                <div class="form-group">
                    <label for="assign-sheet-id">Execution Sheet ID *</label>
                    <input type="text" id="assign-sheet-id" name="executionSheetId" value="${selectedSheet}" required>
                </div>
                <div class="form-group">
                    <label for="assign-operation-id">Operation ID *</label>
                    <input type="text" id="assign-operation-id" name="operationId" required>
                </div>
                <div class="form-group">
                    <label for="assign-parcel-id">Parcel ID *</label>
                    <input type="text" id="assign-parcel-id" name="parcelId" required>
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

        document.getElementById('assign-form').addEventListener('submit', assignOperation);
    };

    async function assignOperation(e) {
        e.preventDefault();
        const formData = new FormData(e.target);
        const data = {
            executionSheetId: formData.get('executionSheetId'),
            operationId: formData.get('operationId'),
            parcelExecutions: [{
                parcelId: formData.get('parcelId'),
                area: parseFloat(formData.get('area'))
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
        if (!hasRole('PO')) {
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
        if (!hasRole('PO')) {
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
        if (!hasRole('PO')) {
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
        if (!hasRole('SDVBO')) {
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
        if (!hasRole('SDVBO')) {
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
        if (!hasRole('PO')) {
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
                        ${hasRole('PO') && !endTime && operatorId === username ? 
                            `<button class="btn-stop" onclick="stopActivityFromModal('${operationId}', '${activityId}')">Stop Activity</button>` : ''}
                        ${hasRole('PO') && endTime ? 
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
    if (!hasRole('PRBO') && !hasRole('SDVBO')) {
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
});