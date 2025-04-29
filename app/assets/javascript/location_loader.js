// This is a non-module script that will run after jQuery and Select2 are loaded
// It will load the location.js script which needs jQuery and Select2

document.addEventListener('DOMContentLoaded', function() {
  // Check if jQuery and Select2 are available in the global scope
  if (typeof jQuery === 'undefined') {
    console.error("jQuery is not available in global scope, location dropdowns will not work");
    return;
  }
  
  if (typeof jQuery.fn.select2 === 'undefined') {
    console.error("Select2 is not available in global scope, location dropdowns will not work");
    return;
  }
  
  console.log("Loading location script with jQuery:", jQuery.fn.jquery, "and Select2 available");
  
  // Create and load the location.js script
  const script = document.createElement('script');
  script.src = '/assets/location.js';
  script.type = 'text/javascript'; // Not a module
  document.head.appendChild(script);
});