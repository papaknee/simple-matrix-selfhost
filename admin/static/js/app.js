// Admin Console JavaScript

// Utility function to make API calls
async function apiCall(endpoint, method = 'GET', body = null) {
    const options = {
        method,
        headers: {
            'Content-Type': 'application/json',
        },
    };
    
    if (body) {
        options.body = JSON.stringify(body);
    }
    
    const response = await fetch(endpoint, options);
    
    if (response.status === 401) {
        window.location.href = '/admin/login';
        return null;
    }
    
    return await response.json();
}

// Display output in a div
function showOutput(elementId, message, type = 'info') {
    const outputDiv = document.getElementById(elementId);
    outputDiv.textContent = message;
    outputDiv.className = 'output show';
    
    if (type === 'error') {
        outputDiv.classList.add('error');
    } else if (type === 'success') {
        outputDiv.classList.add('success');
    }
}

// Hide output div
function hideOutput(elementId) {
    const outputDiv = document.getElementById(elementId);
    outputDiv.className = 'output';
}

// Refresh service status
async function refreshStatus() {
    const statusDiv = document.getElementById('service-status');
    statusDiv.innerHTML = '<p class="loading">Loading...</p>';
    
    try {
        const data = await apiCall('/admin/api/status');
        
        if (data && data.services) {
            if (data.services.length === 0) {
                statusDiv.innerHTML = '<p>No services found</p>';
            } else {
                statusDiv.innerHTML = '';
                data.services.forEach(service => {
                    const serviceDiv = document.createElement('div');
                    serviceDiv.className = 'service-item';
                    
                    if (service.state.toLowerCase().includes('running') || 
                        service.state.toLowerCase().includes('up')) {
                        serviceDiv.classList.add('running');
                    } else {
                        serviceDiv.classList.add('stopped');
                    }
                    
                    serviceDiv.innerHTML = `
                        <div>
                            <div class="service-name">${service.name}</div>
                            <div class="service-status">${service.state} - ${service.status}</div>
                        </div>
                    `;
                    
                    statusDiv.appendChild(serviceDiv);
                });
            }
        }
    } catch (error) {
        statusDiv.innerHTML = `<p class="error">Error loading status: ${error.message}</p>`;
    }
}

// Update repository
async function updateRepo() {
    showOutput('repo-output', 'Updating repository...', 'info');
    
    try {
        const data = await apiCall('/admin/api/update-repo', 'POST');
        
        if (data && data.success) {
            showOutput('repo-output', data.output, 'success');
        } else {
            showOutput('repo-output', data.error || data.output, 'error');
        }
    } catch (error) {
        showOutput('repo-output', `Error: ${error.message}`, 'error');
    }
}

// Update all Docker images
async function updateAllImages() {
    showOutput('image-output', 'Updating all Docker images...', 'info');
    
    try {
        const data = await apiCall('/admin/api/update-images', 'POST');
        
        if (data && data.success) {
            showOutput('image-output', data.output, 'success');
        } else {
            showOutput('image-output', data.error || data.output, 'error');
        }
    } catch (error) {
        showOutput('image-output', `Error: ${error.message}`, 'error');
    }
}

// Update specific Docker image
async function updateImage(service) {
    showOutput('image-output', `Updating ${service} image...`, 'info');
    
    try {
        const data = await apiCall('/admin/api/update-images', 'POST', { service });
        
        if (data && data.success) {
            showOutput('image-output', data.output, 'success');
        } else {
            showOutput('image-output', data.error || data.output, 'error');
        }
    } catch (error) {
        showOutput('image-output', `Error: ${error.message}`, 'error');
    }
}

// Control service (start, stop, restart)
async function controlService(action, service) {
    const serviceName = service || 'all services';
    showOutput('service-output', `${action}ing ${serviceName}...`, 'info');
    
    try {
        const data = await apiCall(`/admin/api/service/${action}`, 'POST', { service });
        
        if (data && data.success) {
            showOutput('service-output', data.output, 'success');
            setTimeout(refreshStatus, 2000); // Refresh status after 2 seconds
        } else {
            showOutput('service-output', data.error || data.output, 'error');
        }
    } catch (error) {
        showOutput('service-output', `Error: ${error.message}`, 'error');
    }
}

// View logs for a service
async function viewLogs(service) {
    const logsPanel = document.getElementById('logs-panel');
    const logsServiceName = document.getElementById('logs-service-name');
    const logsContent = document.getElementById('logs-content');
    
    logsServiceName.textContent = service;
    logsContent.textContent = 'Loading logs...';
    logsPanel.style.display = 'block';
    
    try {
        const data = await apiCall(`/admin/api/logs/${service}?lines=200`);
        
        if (data && data.success) {
            logsContent.textContent = data.logs;
        } else {
            logsContent.textContent = `Error loading logs: ${data.error || 'Unknown error'}`;
        }
    } catch (error) {
        logsContent.textContent = `Error: ${error.message}`;
    }
}

// Close logs panel
function closeLogs() {
    document.getElementById('logs-panel').style.display = 'none';
}

// Create backup
async function createBackup() {
    showOutput('backup-output', 'Creating backup...', 'info');
    
    try {
        const data = await apiCall('/admin/api/backup', 'POST');
        
        if (data && data.success) {
            showOutput('backup-output', data.message, 'success');
        } else {
            showOutput('backup-output', data.error || 'Backup failed', 'error');
        }
    } catch (error) {
        showOutput('backup-output', `Error: ${error.message}`, 'error');
    }
}

// Show schedule form
function showScheduleForm() {
    document.getElementById('schedule-form').style.display = 'block';
}

// Hide schedule form
function hideScheduleForm() {
    document.getElementById('schedule-form').style.display = 'none';
}

// Add new schedule
async function addSchedule(event) {
    event.preventDefault();
    
    const type = document.getElementById('schedule-type').value;
    const schedule = document.getElementById('schedule-time').value;
    
    try {
        const data = await apiCall('/admin/api/schedules', 'POST', {
            type,
            schedule,
            enabled: true
        });
        
        if (data && data.success) {
            hideScheduleForm();
            loadSchedules();
            alert('Schedule added successfully!');
        } else {
            alert(`Error: ${data.error || 'Failed to add schedule'}`);
        }
    } catch (error) {
        alert(`Error: ${error.message}`);
    }
}

// Delete schedule
async function deleteSchedule(scheduleId) {
    if (!confirm('Are you sure you want to delete this schedule?')) {
        return;
    }
    
    try {
        const data = await apiCall(`/admin/api/schedules/${scheduleId}`, 'DELETE');
        
        if (data && data.success) {
            loadSchedules();
        } else {
            alert(`Error: ${data.error || 'Failed to delete schedule'}`);
        }
    } catch (error) {
        alert(`Error: ${error.message}`);
    }
}

// Load schedules
async function loadSchedules() {
    const scheduleList = document.getElementById('schedule-list');
    scheduleList.innerHTML = '<p class="loading">Loading...</p>';
    
    try {
        const data = await apiCall('/admin/api/schedules');
        
        if (data && data.schedules) {
            if (data.schedules.length === 0) {
                scheduleList.innerHTML = '<p>No scheduled tasks. Click "Add Schedule" to create one.</p>';
            } else {
                scheduleList.innerHTML = '';
                data.schedules.forEach(schedule => {
                    const scheduleDiv = document.createElement('div');
                    scheduleDiv.className = 'schedule-item';
                    
                    const nextRun = data.active_jobs.find(j => j.id === schedule.id);
                    const nextRunText = nextRun && nextRun.next_run ? 
                        new Date(nextRun.next_run).toLocaleString() : 
                        'Not scheduled';
                    
                    scheduleDiv.innerHTML = `
                        <div class="schedule-info">
                            <div class="schedule-type">${schedule.type}</div>
                            <div class="schedule-time">
                                Schedule: ${schedule.schedule} | 
                                Next run: ${nextRunText}
                            </div>
                        </div>
                        <div class="schedule-actions">
                            <button onclick="deleteSchedule('${schedule.id}')" class="btn btn-sm btn-danger">
                                Delete
                            </button>
                        </div>
                    `;
                    
                    scheduleList.appendChild(scheduleDiv);
                });
            }
        }
    } catch (error) {
        scheduleList.innerHTML = `<p class="error">Error loading schedules: ${error.message}</p>`;
    }
}

// Load server configuration settings
async function loadServerSettings() {
    try {
        const data = await apiCall('/admin/api/config/server-settings');
        
        if (data && data.success) {
            const settings = data.settings;
            
            // Update registration toggle
            const registrationCheckbox = document.getElementById('enable-registration');
            const registrationStatus = document.getElementById('registration-status');
            if (registrationCheckbox && registrationStatus) {
                registrationCheckbox.checked = settings.enable_registration;
                registrationStatus.textContent = settings.enable_registration ? 'Enabled' : 'Disabled';
                registrationStatus.className = `status-text ${settings.enable_registration ? 'status-enabled' : 'status-disabled'}`;
            }
            
            // Update federation toggle
            const federationCheckbox = document.getElementById('enable-federation');
            const federationStatus = document.getElementById('federation-status');
            if (federationCheckbox && federationStatus) {
                federationCheckbox.checked = settings.enable_federation;
                federationStatus.textContent = settings.enable_federation ? 'Enabled' : 'Disabled';
                federationStatus.className = `status-text ${settings.enable_federation ? 'status-enabled' : 'status-disabled'}`;
            }
        }
    } catch (error) {
        console.error('Error loading server settings:', error);
        const registrationStatus = document.getElementById('registration-status');
        const federationStatus = document.getElementById('federation-status');
        if (registrationStatus) registrationStatus.textContent = 'Error loading';
        if (federationStatus) federationStatus.textContent = 'Error loading';
    }
}

// Update server settings
async function updateServerSettings(settingType, value) {
    const outputDiv = document.getElementById('config-output');
    
    try {
        let body = {};
        if (settingType === 'registration') {
            body.enable_registration = value;
        } else if (settingType === 'federation') {
            body.enable_federation = value;
        }
        
        showOutput('config-output', 'Updating settings and restarting Synapse...', 'info');
        
        const data = await apiCall('/admin/api/config/server-settings', 'POST', body);
        
        if (data && data.success) {
            showOutput('config-output', data.message || 'Settings updated successfully! Waiting for Synapse to restart...', 'success');
            
            // Update status text
            if (settingType === 'registration') {
                const statusText = document.getElementById('registration-status');
                statusText.textContent = value ? 'Enabled' : 'Disabled';
                statusText.className = `status-text ${value ? 'status-enabled' : 'status-disabled'}`;
            } else if (settingType === 'federation') {
                const statusText = document.getElementById('federation-status');
                statusText.textContent = value ? 'Enabled' : 'Disabled';
                statusText.className = `status-text ${value ? 'status-enabled' : 'status-disabled'}`;
            }
            
            // Poll for Synapse to be back up (check service status)
            // Check every 3 seconds, up to 20 attempts (60 seconds total)
            let attempts = 0;
            const maxAttempts = 20;
            const checkInterval = setInterval(async () => {
                attempts++;
                try {
                    const statusData = await apiCall('/admin/api/status');
                    if (statusData && statusData.services) {
                        const synapseService = statusData.services.find(s => s.name === 'synapse');
                        if (synapseService && synapseService.state === 'running') {
                            clearInterval(checkInterval);
                            showOutput('config-output', 'Settings applied successfully! Synapse is running.', 'success');
                            setTimeout(() => {
                                loadServerSettings();
                                hideOutput('config-output');
                            }, 3000);
                        }
                    }
                } catch (error) {
                    // Ignore errors during polling
                }
                
                if (attempts >= maxAttempts) {
                    clearInterval(checkInterval);
                    showOutput('config-output', 'Settings updated, but Synapse restart is taking longer than expected. Please check service status.', 'success');
                    setTimeout(() => {
                        loadServerSettings();
                        hideOutput('config-output');
                    }, 3000);
                }
            }, 3000); // Check every 3 seconds
        } else {
            const errorMsg = data ? (data.error || data.warning || 'Unknown error') : 'Failed to update settings';
            showOutput('config-output', errorMsg, 'error');
            // Revert checkbox
            loadServerSettings();
        }
    } catch (error) {
        showOutput('config-output', `Error: ${error.message}`, 'error');
        // Revert checkbox
        loadServerSettings();
    }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    refreshStatus();
    loadSchedules();
    loadServerSettings();
    
    // Auto-refresh status every 30 seconds
    setInterval(refreshStatus, 30000);
});
