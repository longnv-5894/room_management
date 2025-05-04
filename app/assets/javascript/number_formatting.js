// Number formatting utilities for adding thousands separators
document.addEventListener('DOMContentLoaded', function() {
  // Format numbers with commas as thousands separators
  function formatNumberWithCommas(number) {
    return number.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  }
  
  // Initialize formatting for all number-format fields
  function initializeNumberFormatting() {
    const numberFormatFields = document.querySelectorAll('.number-format');
    
    numberFormatFields.forEach(function(field) {
      // Format on initial load
      if (field.value) {
        field.value = formatNumberWithCommas(field.value);
      }
      
      // Format on input
      field.addEventListener('input', function(e) {
        const value = e.target.value.replace(/,/g, '');
        if (!isNaN(value)) {
          e.target.value = formatNumberWithCommas(value);
        }
      });
      
      // Handle focus - remove commas for editing
      field.addEventListener('focus', function(e) {
        const value = e.target.value.replace(/,/g, '');
        e.target.value = value;
      });
      
      // Format on blur
      field.addEventListener('blur', function(e) {
        const value = e.target.value.replace(/,/g, '');
        if (!isNaN(value)) {
          e.target.value = formatNumberWithCommas(value);
        }
      });
    });
  }

  // Initialize on page load
  initializeNumberFormatting();

  // Make formatting function available globally
  window.formatNumberWithCommas = formatNumberWithCommas;
  window.initializeNumberFormatting = initializeNumberFormatting;
});