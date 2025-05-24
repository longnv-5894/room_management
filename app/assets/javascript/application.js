// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.

// Initialize Rails functionality

// Bootstrap is loaded via CDN in the layout
// No import needed here

// These files should be loaded via standard asset pipeline
// No import needed here for:
// - number_formatting
// - responsive-tables  
// - sync_progress_manager

// jQuery is already included from CDN in the layout
// window.$ and window.jQuery are already defined

// Select2 is already included from CDN in the layout

// Initialize all dropdowns
document.addEventListener('DOMContentLoaded', function() {
  // Initialize all dropdowns - assume bootstrap is loaded globally in window scope
  var dropdownElementList = [].slice.call(document.querySelectorAll('[data-bs-toggle="dropdown"]'))
  if (window.bootstrap && window.bootstrap.Dropdown) {
    var dropdownList = dropdownElementList.map(function (dropdownToggleEl) {
      return new window.bootstrap.Dropdown(dropdownToggleEl)
    })
  }
  
  // Initialize tooltips - assume bootstrap is loaded globally in window scope
  var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'))
  if (window.bootstrap && window.bootstrap.Tooltip) {
    var tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
      return new window.bootstrap.Tooltip(tooltipTriggerEl)
    })
  }
})