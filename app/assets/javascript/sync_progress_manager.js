// filepath: /home/develop/room_management/app/assets/javascript/sync_progress_manager.js
// SyncProgressManager - Quản lý tiến trình đồng bộ liên tục
document.addEventListener('DOMContentLoaded', function() {
  window.SyncProgressManager = {
    // Storage keys
    STORAGE_KEY: 'syncProgressState',
    
    // Default state
    defaultState: {
      active: false,
      jobId: null,
      deviceId: null,
      deviceName: null,
      percent: 0,
      message: 'Đang khởi động đồng bộ...',
      title: 'Đồng bộ dữ liệu',
      completed: false,
      success: true,
      minimized: false,
      lastUpdated: Date.now()
    },
    
    // State
    state: null,
    pollingTimer: null,
    isUpdating: false, // Flag to prevent concurrent updates
    completionHandled: false, // Flag to track if completion was already handled
    
    // Initialize the manager
    init: function() {
      console.log('Initializing SyncProgressManager');
      console.log('DOM state on init:', {
        floatingContainerExists: !!document.getElementById('floating_sync_progress_container'),
        progressBarExists: !!document.getElementById('floating_sync_progress_bar'),
        closeButtonExists: !!document.getElementById('close_progress'),
        minimizeButtonExists: !!document.getElementById('minimize_progress'),
        confirmButtonExists: !!document.getElementById('confirm_progress')
      });
      
      this.loadState();
      this.setupEventListeners();
      
      // If there's an active sync, show the progress bar and start polling
      if (this.state.active && this.state.jobId) {
        console.log('Found active sync, showing progress bar and starting polling:', this.state);
        
        // Set a small timeout to ensure DOM is fully ready
        setTimeout(() => {
          this.showProgressBar();
          
          // Only start polling if not already completed
          if (!this.state.completed) {
            this.startPolling(this.state.jobId);
          }
        }, 300);
      }
    },
    
    // Load state from localStorage
    loadState: function() {
      const savedState = localStorage.getItem(this.STORAGE_KEY);
      
      if (savedState) {
        try {
          this.state = JSON.parse(savedState);
          
          // Check if the state is too old (30 minutes), if so, clear it
          if (Date.now() - this.state.lastUpdated > 30 * 60 * 1000) {
            this.resetState();
          }
        } catch (e) {
          console.error('Error parsing sync progress state:', e);
          this.resetState();
        }
      } else {
        this.resetState();
      }
    },
    
    // Save state to localStorage
    saveState: function() {
      this.state.lastUpdated = Date.now();
      localStorage.setItem(this.STORAGE_KEY, JSON.stringify(this.state));
    },
    
    // Reset state to default
    resetState: function() {
      this.state = {...this.defaultState};
      this.completionHandled = false;
      this.saveState();
    },
    
    // Set up event listeners for the progress bar controls
    setupEventListeners: function() {
      console.log('Setting up event listeners');
      
      // Gắn lại tất cả event listeners
      this.attachListeners();
      
      // Thêm một trình xử lý sự kiện toàn cục cho nút dừng sử dụng event delegation
      document.addEventListener('click', (event) => {
        if (event.target && 
            (event.target.id === 'stop_progress' || 
             (event.target.parentElement && event.target.parentElement.id === 'stop_progress'))) {
          
          console.log('Stop button clicked via global handler', this.state.jobId);
          if (this.state.jobId) {
            this.stopSync(this.state.jobId);
          }
        }
      });
    },
    
    // Phương thức để gắn tất cả event listeners cần thiết
    attachListeners: function() {
      // First check if the container exists
      const container = document.getElementById('floating_sync_progress_container');
      if (!container) {
        console.error('Cannot set up event listeners: floating_sync_progress_container not found in DOM');
        return;
      }

      // Close button
      const closeBtn = document.getElementById('close_progress');
      if (closeBtn) {
        closeBtn.onclick = () => {
          this.hideProgressBar();
          this.stopPolling();
          this.resetState();
        };
      } else {
        console.warn('Close button not found in DOM');
      }

      // Stop button
      const stopBtn = document.getElementById('stop_progress');
      if (stopBtn) {
        stopBtn.onclick = () => {
          console.log('Stop button clicked', this.state.jobId);
          stopBtn.disabled = true;
          stopBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-1"></i> Đang dừng...';
          if (this.state.jobId) {
            this.stopSync(this.state.jobId);
          }
        };
      } else {
        console.warn('Stop button not found in DOM');
      }

      // Minimize button
      const minimizeBtn = document.getElementById('minimize_progress');
      if (minimizeBtn) {
        minimizeBtn.onclick = () => {
          this.toggleMinimize();
        };
      } else {
        console.error('Minimize button not found: minimize_progress');
      }

      // Confirm button (for completed syncs)
      const confirmBtn = document.getElementById('confirm_progress');
      if (confirmBtn) {
        confirmBtn.onclick = () => {
          console.log('Confirm button clicked, deviceId:', this.state.deviceId);
          this.hideProgressBar();
          this.stopPolling();
          if (window.location.pathname.includes('/smart_devices/') && 
              window.location.pathname.includes('/device_unlock_records')) {
            console.log('On unlock records page, refreshing via AJAX');
            setTimeout(() => {
              this.refreshRecordsViaAjax(this.state.deviceId);
            }, 100);
          } else if (window.location.pathname.includes('/smart_devices/') && window.location.pathname.includes('/device_users')) {
            console.log('On device users page, refreshing via AJAX');
            setTimeout(() => {
              this.refreshDeviceUsersViaAjax(this.state.deviceId);
            }, 100);
          } else {
            console.log('Not on unlock records or device users page, reloading the page');
            this.reloadPageWithDelay();
          }
          this.resetState();
        };
      } else {
        console.error('Confirm button not found: confirm_progress');
      }
    },
    
    // Show progress bar
    showProgressBar: function() {
      const container = document.getElementById('floating_sync_progress_container');
      console.log('Showing progress bar, container found:', !!container);
      
      if (!container) {
        console.error('Floating progress container not found in DOM. Container should have ID "floating_sync_progress_container".');
        return;
      }
      
      // If the container is already visible with same completion status, don't re-show it to prevent flickering
      if (container.style.display === 'block' && 
          container.style.opacity === '1') {
        console.log('Progress bar already visible, updating content');
        
        // Still update the UI in case percent or message changed
        this.updateProgressBar(
          this.state.percent, 
          this.state.message, 
          this.state.completed, 
          this.state.success
        );
        return;
      }
      
      // Apply minimized class if needed
      if (this.state.minimized) {
        container.classList.add('minimized');
      } else {
        container.classList.remove('minimized');
      }
      
      // Update title before showing
      const titleElement = document.getElementById('progress_title');
      if (titleElement) {
        titleElement.textContent = this.state.title;
      } else {
        console.error('Progress title element not found. Element should have ID "progress_title".');
      }
      
      // Update UI with current state - must happen before display change
      this.updateProgressBar(
        this.state.percent, 
        this.state.message, 
        this.state.completed, 
        this.state.success
      );
      
      // If not already visible, show with animation
      if (container.style.display !== 'block') {
        // Show container with a smooth transition to prevent flickering
        container.style.transition = 'opacity 0.3s ease';
        container.style.opacity = '0';
        container.style.display = 'block';
        
        // Force layout calculation before transition
        container.offsetHeight;
        
        // Apply fade-in effect
        container.style.opacity = '1';
        console.log('Progress bar now visible with animation');
        
        // Re-attach event listeners to ensure they work
        setTimeout(() => this.attachListeners(), 300);
      }
    },
    
    // Hide progress bar
    hideProgressBar: function() {
      const container = document.getElementById('floating_sync_progress_container');
      if (container) {
        // Fade out smoothly
        container.style.transition = 'opacity 0.3s ease';
        container.style.opacity = '0';
        
        // Hide after transition
        setTimeout(() => {
          container.style.display = 'none';
          // Reset opacity for next show
          container.style.opacity = '1';
        }, 300);
      }
    },
    
    // Toggle minimize state
    toggleMinimize: function() {
      const container = document.getElementById('floating_sync_progress_container');
      if (container) {
        this.state.minimized = !this.state.minimized;
        
        if (this.state.minimized) {
          container.classList.add('minimized');
        } else {
          container.classList.remove('minimized');
        }
        
        this.saveState();
      }
    },
    
    // Start sync for a device
    startSync: function(deviceId, jobId, deviceName) {
      console.log('Starting sync for device:', deviceId, jobId, deviceName);
      this.stopPolling(); // Stop any existing polling
      
      // Update state
      this.state.active = true;
      this.state.jobId = jobId;
      this.state.deviceId = deviceId;
      this.state.deviceName = deviceName;
      this.state.percent = 0;
      this.state.message = 'Đang khởi động đồng bộ...';
      this.state.title = deviceName ? `Đồng bộ ${deviceName}` : 'Đồng bộ dữ liệu';
      this.state.completed = false;
      this.state.success = true;
      this.state.minimized = false;
      this.completionHandled = false;
      
      this.saveState();
      
      // First reset any previous styling by forcing a reset
      const progressBar = document.getElementById('floating_sync_progress_bar');
      if (progressBar) {
        const barElement = progressBar.querySelector('.progress-bar');
        const progressElement = progressBar.querySelector('.sync-progress');
        
        if (barElement) {
          // Use className to completely reset all classes at once
          barElement.className = 'progress-bar bg-primary';
          barElement.style.width = '0%';
          barElement.setAttribute('aria-valuenow', 0);
          barElement.textContent = '0%';
        }
        
        if (progressElement) {
          progressElement.classList.remove('completed', 'error', 'stopped');
        }
      }
      
      // Show stop button and hide confirm button
      const actionsContainer = document.getElementById('progress_actions');
      const stopButton = document.getElementById('stop_progress');
      const confirmButton = document.getElementById('confirm_progress');
      
      if (actionsContainer) {
        actionsContainer.classList.remove('d-none');
      }
      
      if (stopButton) {
        stopButton.classList.remove('d-none');
      }
      
      if (confirmButton) {
        confirmButton.classList.add('d-none');
      }
      
      // Show progress bar with a short delay to ensure reset takes effect
      setTimeout(() => {
        this.showProgressBar();
        
        // Start polling for updates
        this.startPolling(jobId);
      }, 100);
    },
    
    // Start polling for job progress
    startPolling: function(jobId) {
      // Clear any existing polling interval
      this.stopPolling();
      
      // Don't start polling if already completed
      if (this.state.completed) {
        console.log('Not starting polling - job already completed');
        return;
      }
      
      // Poll immediately for the first update
      this.pollJobProgress(jobId);
      
      // Set up new polling interval (every 3 seconds - increased to reduce flickering)
      this.pollingTimer = setInterval(() => {
        if (!this.isUpdating) {
          this.pollJobProgress(jobId);
        } else {
          console.log('Skipping poll, update already in progress');
        }
      }, 3000);
    },
    
    // Stop the sync process by sending a request to the server
    stopSync: function(jobId) {
      console.log('Requesting to stop sync for job:', jobId);
      
      // Get CSRF token - handle different ways it might be available
      let csrfToken = '';
      const metaTag = document.querySelector('meta[name="csrf-token"]');
      if (metaTag) {
        csrfToken = metaTag.getAttribute('content');
      } else {
        // Try to get from hidden input if meta tag isn't available
        const csrfInput = document.querySelector('input[name="authenticity_token"]');
        if (csrfInput) {
          csrfToken = csrfInput.value;
        }
      }
      
      fetch(`/smart_devices/stop_sync_job/${jobId}`, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
          'X-Requested-With': 'XMLHttpRequest'
        },
        credentials: 'same-origin' // Include cookies for authentication
      })
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.json();
      })
      .then(data => {
        console.log('Stop sync response:', data);
        
        if (data.success) {
          // Update state with stopping status
          this.state.message = data.message || "Đang dừng đồng bộ, vui lòng đợi... Đang hoàn tác những thay đổi.";
          this.state.status = "stopping";
          this.saveState();
          
          // Change the UI to indicate stopping with warning color and animation
          this.updateProgressBar(
            this.state.percent, 
            this.state.message, 
            false, 
            false, 
            true // isStopping
          );
          
          // Disable the stop button as stopping is already in progress
          const stopBtn = document.getElementById('stop_progress');
          if (stopBtn) {
            stopBtn.classList.add('d-none');
            stopBtn.disabled = true;
          }
          
          // Continue polling to get the final stopped status
          if (!this.pollingTimer) {
            this.startPolling(jobId);
          }
        } else if (data.error) {
          console.error('Error stopping sync:', data.error);
        }
      })
      .catch(error => {
        console.error('Error stopping sync:', error);
      });
    },
    
    // Stop polling
    stopPolling: function() {
      if (this.pollingTimer) {
        clearInterval(this.pollingTimer);
        this.pollingTimer = null;
      }
    },
    
    // Poll for job progress
    pollJobProgress: function(jobId) {
      // Don't make redundant polls if already completed
      if (this.state.completed) {
        console.log('Job already completed, stopping polling');
        this.stopPolling();
        return;
      }
      
      // Skip if we're already updating to prevent race conditions
      if (this.isUpdating) {
        console.log('Skipping poll - update already in progress');
        return;
      }
      
      // Set updating flag to prevent concurrent updates
      this.isUpdating = true;
      
      fetch(`/smart_devices/job_progress/${jobId}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
        cache: 'no-store' // Prevent browser caching
      })
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.json();
      })
      .then(data => {
        console.log('Progress update received:', data);
        
        if (data.error) {
          // Error occurred during processing
          console.log('Error in job:', data.error);
          
          // Update state first
          this.state.percent = 100;
          this.state.message = data.error;
          this.state.completed = true;
          this.state.success = false;
          this.saveState();
          
          // Then update UI - only once
          this.updateProgressBar(100, data.error, true, false);
          
          // Stop polling
          this.stopPolling();
        } else if (data.status === "stopping") {
          // Job is in the process of stopping
          console.log('Job is in the process of stopping');
          
          // Update state
          this.state.percent = data.percent || this.state.percent;
          this.state.message = data.message || "Đang dừng đồng bộ, vui lòng đợi...";
          this.state.completed = false;
          this.state.success = false;
          this.saveState();
          
          // Update UI with stopping state (animated warning)
          this.updateProgressBar(
            this.state.percent, 
            this.state.message, 
            false, 
            false, 
            true // isStopping flag
          );
          
          // Hide stop button as stopping is already in progress
          const stopBtn = document.getElementById('stop_progress');
          if (stopBtn) {
            stopBtn.classList.add('d-none');
          }
          
          // Continue polling to get the final stopped status
          this.isUpdating = false;
        } else if (data.stopped || data.status === "stopped") {
          // Job was stopped by user request
          console.log('Job was stopped by user request');
          
          // Stop polling immediately
          this.stopPolling();
          
          // Skip update if we've already handled completion
          if (this.completionHandled) {
            console.log('Completion already handled, skipping update to prevent flickering');
            return;
          }
          
          // Mark that we've handled completion to prevent multiple updates
          this.completionHandled = true;
          
          // Update state
          this.state.percent = 100;
          this.state.message = data.message || "Đã dừng đồng bộ";
          this.state.completed = true;
          this.state.success = false; // Stopped jobs are considered not successful
          this.saveState();
          
          // Update UI with stopped state
          this.updateProgressBar(100, data.message || "Đã dừng đồng bộ", true, false);
          
          // Show confirmation button
          const actionsContainer = document.getElementById('progress_actions');
          if (actionsContainer) {
            actionsContainer.classList.remove('d-none');
          }
          
          // Hide stop button as it's no longer needed
          const stopBtn = document.getElementById('stop_progress');
          if (stopBtn) {
            stopBtn.classList.add('d-none');
          }
        } else if (data.completed) {
          console.log('Job completed successfully');
          
          // Stop polling immediately
          this.stopPolling();
          
          // Skip update if we've already handled completion
          if (this.completionHandled) {
            console.log('Completion already handled, skipping update to prevent flickering');
            return;
          }
          
          // Mark that we've handled completion to prevent multiple updates
          this.completionHandled = true;
          
          // Update state 
          this.state.percent = 100;
          this.state.message = data.message || "Đồng bộ hoàn tất";
          this.state.completed = true;
          this.state.success = data.success !== false;
          this.saveState();
          
          // Update UI with final state - immediately
          this.updateProgressBar(100, data.message || "Đồng bộ hoàn tất", true, data.success !== false);
          
          // If we're on the device's records page, refresh data via AJAX instead of reloading the page
          if (window.location.pathname.includes('/smart_devices/') && 
              window.location.pathname.includes('/device_unlock_records') &&
              window.location.pathname.includes('/' + this.state.deviceId + '/')) {
            
            // Refresh data via AJAX after a short delay
            setTimeout(() => {
              this.refreshRecordsViaAjax(this.state.deviceId);
            }, 1000);
          }
        } else {
          // Job is still in progress
          // Don't update UI if percent hasn't changed (reduces flickering)
          if (this.state.percent !== data.percent) {
            this.updateProgressBar(
              data.percent || 0, 
              data.message || "Đang đồng bộ...", 
              false, 
              true
            );
            
            // Update state
            this.state.percent = data.percent || 0;
            this.state.message = data.message || "Đang đồng bộ...";
            this.saveState();
          }
        }
      })
      .catch(error => {
        console.error('Error polling progress:', error);
        
        // After several failed attempts, we could stop polling
        // For now we'll just continue in case it's a temporary network issue
      })
      .finally(() => {
        // Clear updating flag after a longer delay to prevent rapid consecutive updates
        setTimeout(() => {
          this.isUpdating = false;
        }, 500);
      });
    },
    
    // Update the progress bar UI
    updateProgressBar: function(percent, message, completed = false, success = true, isStopping = false) {
      const progressBar = document.getElementById('floating_sync_progress_bar');
      
      // Make sure percent is a valid number
      percent = parseInt(percent);
      if (isNaN(percent)) percent = 0;
      
      console.log(`Updating floating progress bar: ${percent}% - ${message} - completed: ${completed}, success: ${success}, stopping: ${isStopping}`);
      
      if (progressBar) {
        // Get reference to all elements we need to update
        const barElement = progressBar.querySelector('.progress-bar');
        const messageElement = progressBar.querySelector('.progress-message');
        const progressElement = progressBar.querySelector('.sync-progress');
        
        if (barElement) {
          // Always ensure transition is set for smooth animation
          if (!barElement.style.transition) {
            barElement.style.transition = 'width 0.8s ease-in-out, background-color 0.5s ease';
          }
          
          // Update width with animation
          barElement.style.width = `${percent}%`;
          barElement.setAttribute('aria-valuenow', percent);
          barElement.textContent = `${percent}%`;
          
          // Detect stopping state from message if not explicitly passed
          isStopping = isStopping || (message && message.toLowerCase().includes('đang dừng'));
          const isStopped = message && 
                           (message.includes('Đã dừng') || 
                            message.includes('dừng đồng bộ'));
          
          // Ensure consistent class application
          if (completed) {
            // For completed state
            if (success) {
              barElement.className = 'progress-bar bg-success';
            } else {
              if (isStopped) {
                barElement.className = 'progress-bar bg-warning';
              } else {
                barElement.className = 'progress-bar bg-danger';
              }
            }
          } else if (isStopping) {
            // For stopping state (in progress but stopping)
            barElement.className = 'progress-bar bg-warning progress-bar-striped progress-bar-animated';
          } else {
            // For regular in-progress state
            barElement.className = 'progress-bar bg-primary';
          }
        }
        
        // Update the message
        if (messageElement) {
          messageElement.textContent = message;
        }
        
        // Ensure container class is consistent
        if (progressElement) {
          progressElement.classList.remove('completed', 'error', 'stopped', 'stopping');
          
          if (completed) {
            if (success) {
              progressElement.classList.add('completed');
            } else {
              if (isStopped) {
                progressElement.classList.add('stopped');
              } else {
                progressElement.classList.add('error');
              }
            }
          } else if (isStopping) {
            progressElement.classList.add('stopping');
          }
        }
        
        // Show/hide action buttons for completed syncs or stopping state
        const actionsContainer = document.getElementById('progress_actions');
        const stopButton = document.getElementById('stop_progress');
        const confirmButton = document.getElementById('confirm_progress');
        
        if (actionsContainer) {
          if (completed || isStopping) {
            // Show actions container when completed or stopping
            actionsContainer.classList.remove('d-none');
            
            // Hide stop button when completed or already stopping
            if (stopButton) {
              stopButton.classList.add('d-none');
            }
            
            // Show confirm button for completed state, hide for stopping state
            if (confirmButton) {
              if (completed) {
                confirmButton.classList.remove('d-none');
              } else if (isStopping) {
                confirmButton.classList.add('d-none');
              }
            }
          } else {
            // For in-progress state
            // Show stop button, hide confirm button
            if (stopButton) {
              stopButton.classList.remove('d-none');
            }
            
            // Show actions container to display stop button
            actionsContainer.classList.remove('d-none');
            
            // Hide confirm button during in-progress
            if (confirmButton) {
              confirmButton.classList.add('d-none');
            }
          }
        }
      } else {
        console.error('Progress bar element not found');
      }
    },
    
    // Helper method to update pagination and record count
    // Fallback method when AJAX update fails
    fallbackTableUpdate: function(deviceId) {
      console.log('Trying fallback table update method');
      
      // Kiểm tra xem có thẻ tbody trong DOM không
      const tableBody = document.querySelector('table.data-table tbody');
      if (!tableBody) {
        console.error('Cannot find table body for fallback update');
        this.reloadPageWithDelay();
        return;
      }
      
      // Hiển thị thông báo đang làm mới
      const messageDiv = document.createElement('div');
      messageDiv.className = 'alert alert-info m-3';
      messageDiv.innerHTML = '<i class="fas fa-sync fa-spin me-2"></i> Đang làm mới dữ liệu...';
      
      // Tìm vị trí để thêm thông báo
      const cardBody = document.querySelector('.card-body');
      if (cardBody) {
        cardBody.prepend(messageDiv);
      }
      
      // Thử lại tải lại trang sau 800ms
      setTimeout(() => {
        this.reloadPageWithDelay();
      }, 800);
    },
    
    // Simple helper to reload page with delay
    reloadPageWithDelay: function() {
      console.log('Falling back to page reload');
      window.location.reload();
    },
    
    updatePaginationAndCount: function(tempDiv) {
      // Try to update pagination
      try {
        // Đầu tiên thử với ID
        const newPagination = tempDiv.querySelector('#records-pagination');
        const currentPagination = document.querySelector('#records-pagination');
        
        if (newPagination && currentPagination) {
          currentPagination.innerHTML = newPagination.innerHTML;
          console.log('Pagination updated successfully via ID');
        } else {
          // Thử với class
          const paginationContainer = document.querySelector('.d-flex.justify-content-center.p-3');
          const newPaginationContainer = tempDiv.querySelector('.d-flex.justify-content-center.p-3');
          
          if (paginationContainer && newPaginationContainer) {
            paginationContainer.innerHTML = newPaginationContainer.innerHTML;
            console.log('Pagination updated successfully via class selector');
          }
        }
      } catch (err) {
        console.error('Error updating pagination:', err);
      }
      
      // Try to update record count
      try {
        const newTotalCount = tempDiv.querySelector('#records-count');
        const currentTotalCount = document.querySelector('#records-count');
        
        if (newTotalCount && currentTotalCount) {
          currentTotalCount.innerHTML = newTotalCount.innerHTML;
          console.log('Total count updated successfully');
        } else {
          // Thử tìm với class hoặc nội dung
          const countDisplay = document.querySelector('.fw-medium');
          const newCountDisplay = tempDiv.querySelector('.fw-medium');
          
          if (countDisplay && newCountDisplay && 
              (countDisplay.textContent.includes('bản ghi') || 
               countDisplay.textContent.includes('records'))) {
            countDisplay.innerHTML = newCountDisplay.innerHTML;
            console.log('Record count updated via class selector');
          }
        }
      } catch (err) {
        console.error('Error updating record count:', err);
      }
    },
    
    // Refresh unlock records via AJAX instead of reloading the page
    refreshRecordsViaAjax: function(deviceId) {
      console.log('Refreshing unlock records via AJAX for device', deviceId);
      
      // Get current URL and query parameters
      const currentUrl = window.location.href;
      
      // Add a log to debug URL
      console.log('Refreshing data from URL:', currentUrl);
      
      // Make an AJAX request to get the current page content
      fetch(currentUrl, {
        method: 'GET',
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        },
        cache: 'no-store'
      })
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.text();
      })
      .then(html => {
        console.log('AJAX response received, length:', html.length);
        
        try {
          // Create a temporary element to parse the HTML
          const tempDiv = document.createElement('div');
          tempDiv.innerHTML = html;
          
          // Cách 1: Cố gắng thay thế thẻ div chứa tất cả
          const cardBody = document.querySelector('.card-body');
          if (cardBody) {
            const newCardBody = tempDiv.querySelector('.card-body');
            if (newCardBody) {
              cardBody.innerHTML = newCardBody.innerHTML;
              console.log('Updated card-body container successfully');
              return; // Nếu đã cập nhật thành công thì thoát
            }
          }
          
          // Cách 2: Thay thế toàn bộ bảng dữ liệu
          const dataTable = document.querySelector('.data-table');
          if (dataTable) {
            const newDataTable = tempDiv.querySelector('.data-table');
            if (newDataTable) {
              dataTable.outerHTML = newDataTable.outerHTML;
              console.log('Updated entire data-table successfully');
              
              // Cập nhật phân trang và số lượng bản ghi riêng biệt
              this.updatePaginationAndCount(tempDiv);
              return;
            }
          }
          
          // Cách 3: Cập nhật từng thành phần riêng lẻ
          const tableBody = document.querySelector('.data-table tbody');
          const newTableBody = tempDiv.querySelector('.data-table tbody');
          
          if (tableBody && newTableBody) {
            tableBody.innerHTML = newTableBody.innerHTML;
            console.log('Updated table body successfully');
            
            // Cập nhật phân trang và số lượng bản ghi
            this.updatePaginationAndCount(tempDiv);
            return;
          }
          
          // Nếu tất cả các cách trên đều thất bại, log lỗi chi tiết
          console.error('Could not find matching elements to update the table', {
            cardBodyExists: !!document.querySelector('.card-body'),
            newCardBodyExists: !!tempDiv.querySelector('.card-body'),
            dataTableExists: !!document.querySelector('.data-table'),
            newDataTableExists: !!tempDiv.querySelector('.data-table'),
            tableBodyExists: !!document.querySelector('.data-table tbody'),
            newTableBodyExists: !!tempDiv.querySelector('.data-table tbody')
          });
        } catch (err) {
          console.error('Error updating table contents:', err);
        }
        
        console.log('Records refreshed via AJAX without page reload');
        
        // Trigger a custom event to notify any other components that the data has been refreshed
        const refreshEvent = new CustomEvent('recordsRefreshed', {
          detail: { deviceId: deviceId, success: true }
        });
        document.dispatchEvent(refreshEvent);
      })
      .catch(error => {
        console.error('Error refreshing unlock records:', error);
        
        // Trigger a custom event to notify any other components about the error
        const refreshEvent = new CustomEvent('recordsRefreshed', {
          detail: { deviceId: deviceId, success: false, error: error.message }
        });
        document.dispatchEvent(refreshEvent);
        
        // On error, try a simple alternative update approach before falling back to reload
        this.fallbackTableUpdate(deviceId);
      });
    },
    
    // Refresh device users via AJAX instead of reloading the page
    refreshDeviceUsersViaAjax: function(deviceId) {
      console.log('Refreshing device users via AJAX for device', deviceId);
      const currentUrl = window.location.href;
      console.log('Refreshing device users from URL:', currentUrl);
      
      // Đầu tiên, hiển thị thông báo đang làm mới
      const messageDiv = document.createElement('div');
      messageDiv.className = 'alert alert-info mb-3';
      messageDiv.innerHTML = '<i class="fas fa-sync fa-spin me-2"></i> Đang làm mới danh sách người dùng...';
      
      // Tìm vị trí để thêm thông báo tạm thời
      const infoSection = document.querySelector('.container-fluid');
      if (infoSection) {
        infoSection.insertBefore(messageDiv, infoSection.firstChild);
      }
      
      fetch(currentUrl, {
        method: 'GET',
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        },
        cache: 'no-store'
      })
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.text();
      })
      .then(html => {
        console.log('AJAX response for device users received, length:', html.length);
        
        // Xóa thông báo đang làm mới nếu có
        if (messageDiv && messageDiv.parentNode) {
          messageDiv.parentNode.removeChild(messageDiv);
        }
        
        try {
          const tempDiv = document.createElement('div');
          tempDiv.innerHTML = html;
          
          // Cập nhật thống kê số người dùng (cards phía trên)
          const newStatsCards = tempDiv.querySelectorAll('.col-xl-3.col-md-6.mb-4');
          const currentStatsCards = document.querySelectorAll('.col-xl-3.col-md-6.mb-4');
          
          if (newStatsCards && newStatsCards.length > 0 && currentStatsCards && currentStatsCards.length > 0) {
            // Cập nhật thông tin thống kê
            for (let i = 0; i < Math.min(newStatsCards.length, currentStatsCards.length); i++) {
              currentStatsCards[i].innerHTML = newStatsCards[i].innerHTML;
            }
            console.log('User stats cards updated successfully');
          }
          
          // PHƯƠNG PHÁP CHÍNH: Dựa vào cấu trúc chính xác của device_users.html.erb
          // Tìm card chứa bảng người dùng - là card đầu tiên
          const userCards = document.querySelectorAll('.card.border-0.shadow.mb-4');
          const newUserCards = tempDiv.querySelectorAll('.card.border-0.shadow.mb-4');
          
          if (userCards.length > 0 && newUserCards.length > 0) {
            // Card đầu tiên là card chứa bảng người dùng theo cấu trúc HTML
            const userTableCard = userCards[0];
            const newUserTableCard = newUserCards[0];
            
            // Kiểm tra thêm nếu card chứa đúng header
            const cardHeader = userTableCard.querySelector('.card-header h6');
            if (cardHeader && (cardHeader.textContent.includes('người dùng') || 
                                cardHeader.textContent.includes('Authorized Users'))) {
              
              // Cập nhật nội dung card-body
              const cardBody = userTableCard.querySelector('.card-body');
              const newCardBody = newUserTableCard.querySelector('.card-body');
              
              if (cardBody && newCardBody) {
                cardBody.innerHTML = newCardBody.innerHTML;
                console.log('Device users table updated successfully through direct card-body match');
                
                // Khởi tạo lại các event listeners cho các nút trong bảng
                this.reinitializeTableButtons();
                return;
              }
            }
          }
          
          // PHƯƠNG PHÁP DỰ PHÒNG 1: Dựa vào nội dung tiêu đề chính xác
          const cards = document.querySelectorAll('.card.border-0.shadow.mb-4');
          const newCards = tempDiv.querySelectorAll('.card.border-0.shadow.mb-4');
          
          // Duyệt qua tất cả các card để tìm card chứa đúng tiêu đề
          for (let i = 0; i < cards.length; i++) {
            const header = cards[i].querySelector('.card-header h6.font-weight-bold');
            if (header && header.textContent.includes(window.I18n ? 
                I18n.t('smart_devices.lock_users.authorized_users') : 'Authorized Users')) {
              
              // Tìm card tương ứng trong HTML mới
              const newHeader = newCards[i] ? newCards[i].querySelector('.card-header h6.font-weight-bold') : null;
              if (newHeader && newHeader.textContent.includes(window.I18n ? 
                  I18n.t('smart_devices.lock_users.authorized_users') : 'Authorized Users')) {
                
                // Cập nhật nội dung của card-body
                const cardBody = cards[i].querySelector('.card-body');
                const newCardBody = newCards[i].querySelector('.card-body');
                
                if (cardBody && newCardBody) {
                  cardBody.innerHTML = newCardBody.innerHTML;
                  console.log('Device users table updated successfully through header match');
                  
                  // Khởi tạo lại các event listeners cho các nút trong bảng
                  this.reinitializeTableButtons();
                  return;
                }
              }
            }
          }
          
          // PHƯƠNG PHÁP DỰ PHÒNG 2: Tìm thẻ table hoặc thông báo "no_users_message"
          const tableContainer = document.querySelector('.table-responsive');
          const newTableContainer = tempDiv.querySelector('.table-responsive');
          
          // Nếu có bảng (trường hợp có người dùng)
          if (tableContainer && newTableContainer) {
            tableContainer.innerHTML = newTableContainer.innerHTML;
            console.log('Device users table updated successfully through table container match');
            
            // Khởi tạo lại các event listeners cho các nút trong bảng
            this.reinitializeTableButtons();
            return;
          }
          
          // Nếu không có bảng, tìm thông báo "không có người dùng"
          const noUsersAlert = document.querySelector('.alert.alert-info');
          const newNoUsersAlert = tempDiv.querySelector('.alert.alert-info');
          
          if (noUsersAlert && newNoUsersAlert) {
            noUsersAlert.innerHTML = newNoUsersAlert.innerHTML;
            console.log('No users message updated successfully');
            return;
          }
          
          // Nếu tất cả cách trên thất bại, reload trang
          console.warn('Could not find matching elements to update device users list');
          this.reloadPageWithDelay();
          
        } catch (err) {
          console.error('Error updating device users table:', err);
          // Trong trường hợp lỗi, reload toàn bộ trang
          this.reloadPageWithDelay();
        }
        
        // Trigger a custom event
        const refreshEvent = new CustomEvent('deviceUsersRefreshed', {
          detail: { deviceId: deviceId, success: true }
        });
        document.dispatchEvent(refreshEvent);
      })
      .catch(error => {
        // Xóa thông báo đang làm mới nếu có
        if (messageDiv && messageDiv.parentNode) {
          messageDiv.parentNode.removeChild(messageDiv);
        }
        
        console.error('Error refreshing device users:', error);
        const refreshEvent = new CustomEvent('deviceUsersRefreshed', {
          detail: { deviceId: deviceId, success: false, error: error.message }
        });
        document.dispatchEvent(refreshEvent);
        this.reloadPageWithDelay(); // Trong trường hợp lỗi, reload toàn bộ trang
      });
    },
    
    // Khởi tạo lại các event listeners cho các nút trong bảng
    reinitializeTableButtons: function() {
      // Khởi tạo lại Select2 nếu có
      if (typeof jQuery !== 'undefined' && typeof jQuery.fn.select2 !== 'undefined') {
        $('.select2').select2({
          theme: 'bootstrap4'
        });
      }
      
      // Khởi tạo lại các nút modal
      const modals = document.querySelectorAll('.modal');
      if (window.bootstrap && window.bootstrap.Modal && modals.length > 0) {
        modals.forEach(modalEl => {
          new bootstrap.Modal(modalEl);
        });
      }
    }
  };
  
  // Initialize the manager
  SyncProgressManager.init();
});

// Make sure SyncProgressManager is initialized
// This is a fallback in case the DOMContentLoaded event has already fired
if (document.readyState === 'complete' || document.readyState === 'interactive') {
  console.log('Document already loaded, initializing SyncProgressManager directly');
  if (window.SyncProgressManager && typeof window.SyncProgressManager.init === 'function') {
    window.SyncProgressManager.init();
  }
}
