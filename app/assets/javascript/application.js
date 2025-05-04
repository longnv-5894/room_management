// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.

// Initialize Rails functionality

// Bootstrap JavaScript
import * as bootstrap from 'bootstrap'
window.bootstrap = bootstrap

// Import our custom number formatting utilities
import './number_formatting'

// jQuery is already included from CDN in the layout
// window.$ and window.jQuery are already defined

// Select2 is already included from CDN in the layout

// Initialize all dropdowns
document.addEventListener('DOMContentLoaded', function() {
  // Initialize all dropdowns
  var dropdownElementList = [].slice.call(document.querySelectorAll('[data-bs-toggle="dropdown"]'))
  var dropdownList = dropdownElementList.map(function (dropdownToggleEl) {
    return new bootstrap.Dropdown(dropdownToggleEl)
  })
  
  // Initialize tooltips
  var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'))
  var tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
    return new bootstrap.Tooltip(tooltipTriggerEl)
  })
})