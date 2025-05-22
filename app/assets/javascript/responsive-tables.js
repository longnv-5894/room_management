// Responsive tables functionality
document.addEventListener('DOMContentLoaded', function() {
  // Add responsive wrappers to tables that need them
  const tables = document.querySelectorAll('.data-table:not(.table-responsive)');
  tables.forEach(function(table) {
    if (!table.closest('.table-responsive')) {
      const wrapper = document.createElement('div');
      wrapper.className = 'table-responsive';
      table.parentNode.insertBefore(wrapper, table);
      wrapper.appendChild(table);
    }
  });
  
  // Add data-label attributes to cells for mobile view based on headers
  const responsiveTables = document.querySelectorAll('table.data-table');
  responsiveTables.forEach(function(table) {
    const headerCells = table.querySelectorAll('thead th');
    const headerTexts = Array.from(headerCells).map(cell => cell.textContent.trim());
    
    const bodyRows = table.querySelectorAll('tbody tr');
    bodyRows.forEach(function(row) {
      const cells = row.querySelectorAll('td');
      cells.forEach(function(cell, index) {
        if (headerTexts[index]) {
          cell.setAttribute('data-label', headerTexts[index]);
        }
      });
    });
  });
  
  // Add touchmove handler for smooth scrolling on touch devices
  const tableWrappers = document.querySelectorAll('.table-responsive');
  tableWrappers.forEach(function(wrapper) {
    wrapper.addEventListener('touchmove', function(e) {
      e.stopPropagation();
    }, { passive: true });
  });
  
  // Handle table overflow indicators
  function handleTableOverflow() {
    document.querySelectorAll('.table-responsive').forEach(function(wrapper) {
      const hasOverflow = wrapper.scrollWidth > wrapper.clientWidth;
      wrapper.classList.toggle('has-overflow', hasOverflow);
      
      if (hasOverflow && !wrapper.querySelector('.table-scroll-hint')) {
        const hint = document.createElement('div');
        hint.className = 'table-scroll-hint';
        hint.innerHTML = '<i class="fas fa-arrows-left-right"></i>';
        wrapper.appendChild(hint);
        
        // Hide hint after user has scrolled
        wrapper.addEventListener('scroll', function() {
          hint.style.opacity = '0';
          setTimeout(() => {
            hint.remove();
          }, 300);
        }, { once: true });
      }
    });
  }
  
  // Run overflow check on load and resize
  window.addEventListener('resize', handleTableOverflow);
  handleTableOverflow();
});