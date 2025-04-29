// Location dropdown and autocomplete functionality

document.addEventListener('DOMContentLoaded', function() {
  console.log("DOM Content Loaded - Location.js");
  
  // Create autocomplete text inputs for each location dropdown
  setupAutocompleteFields();
  
  // Handle location selections
  setupLocationHandlers();
  
  function setupAutocompleteFields() {
    // For each select dropdown, create an autocomplete text input
    $('.location-select').each(function() {
      const select = $(this);
      const id = select.attr('id');
      const name = select.attr('name');
      const placeholder = select.data('placeholder') || 'Chọn...';
      
      // Hide the original select
      select.css('display', 'none');
      
      // Create a wrapper div for our custom UI
      const wrapper = $('<div class="autocomplete-wrapper"></div>');
      select.after(wrapper);
      
      // Create text input for autocomplete
      const textInput = $('<input type="text" class="form-control autocomplete-input" />');
      textInput.attr('id', id + '_autocomplete');
      textInput.attr('placeholder', placeholder);
      textInput.attr('autocomplete', 'off');
      
      // Create dropdown for suggestions
      const dropdown = $('<div class="autocomplete-dropdown"></div>');
      
      // Add to DOM
      wrapper.append(textInput).append(dropdown);
      
      // Initialize with existing selection if any
      const selectedOption = select.find('option:selected');
      if (selectedOption.val()) {
        textInput.val(selectedOption.text());
      }
      
      // Style the dropdown
      dropdown.css({
        'position': 'absolute',
        'width': '100%',
        'max-height': '200px',
        'overflow-y': 'auto',
        'background': '#fff',
        'border': '1px solid #dee2e6',
        'border-top': 'none',
        'border-radius': '0 0 4px 4px',
        'box-shadow': '0 6px 12px rgba(0,0,0,0.15)',
        'z-index': '1000',
        'display': 'none'
      });
      
      // Setup event listeners for the autocomplete
      textInput.on('input', function() {
        const value = $(this).val().toLowerCase();
        dropdown.empty();
        dropdown.hide();
        
        if (value.length < 1) return;
        
        let matches = 0;
        select.find('option').each(function() {
          const option = $(this);
          if (option.val() === '') return; // Skip empty option
          
          const text = option.text().toLowerCase();
          // Search with and without diacritics
          if (text.indexOf(value) > -1 || removeDiacritics(text).indexOf(removeDiacritics(value)) > -1) {
            const item = $('<div class="autocomplete-item"></div>');
            item.text(option.text());
            item.data('value', option.val());
            item.css({
              'padding': '8px 12px',
              'cursor': 'pointer',
              'border-bottom': '1px solid #f0f0f0'
            });
            
            item.on('mouseenter', function() {
              $(this).css('background-color', '#f0f0ff');
            });
            
            item.on('mouseleave', function() {
              $(this).css('background-color', '');
            });
            
            item.on('click', function() {
              const selectedValue = $(this).data('value');
              const selectedText = $(this).text();
              
              textInput.val(selectedText);
              select.val(selectedValue).trigger('change');
              dropdown.hide();
            });
            
            dropdown.append(item);
            matches++;
          }
        });
        
        if (matches > 0) {
          dropdown.show();
        }
      });
      
      // Show all options when focusing on empty field
      textInput.on('focus', function() {
        if ($(this).val() === '') {
          dropdown.empty();
          
          select.find('option').each(function() {
            const option = $(this);
            if (option.val() === '') return; // Skip empty option
            
            const item = $('<div class="autocomplete-item"></div>');
            item.text(option.text());
            item.data('value', option.val());
            item.css({
              'padding': '8px 12px',
              'cursor': 'pointer',
              'border-bottom': '1px solid #f0f0f0'
            });
            
            item.on('mouseenter', function() {
              $(this).css('background-color', '#f0f0ff');
            });
            
            item.on('mouseleave', function() {
              $(this).css('background-color', '');
            });
            
            item.on('click', function() {
              const selectedValue = $(this).data('value');
              const selectedText = $(this).text();
              
              textInput.val(selectedText);
              select.val(selectedValue).trigger('change');
              dropdown.hide();
            });
            
            dropdown.append(item);
          });
          
          if (dropdown.children().length > 0) {
            dropdown.show();
          }
        }
      });
      
      // Handle clicking outside
      $(document).on('click', function(event) {
        if (!$(event.target).closest('.autocomplete-wrapper').length) {
          dropdown.hide();
        }
      });
      
      // Handle keyboard navigation
      textInput.on('keydown', function(e) {
        const items = dropdown.find('.autocomplete-item');
        const focused = dropdown.find('.focused');
        
        // Down arrow
        if (e.keyCode === 40) {
          e.preventDefault();
          
          if (focused.length === 0) {
            items.first().addClass('focused').css('background-color', '#e0e0ff');
          } else {
            const next = focused.next();
            if (next.length) {
              focused.removeClass('focused').css('background-color', '');
              next.addClass('focused').css('background-color', '#e0e0ff');
              
              // Scroll into view if needed
              const dropdownHeight = dropdown.height();
              const itemOffset = next.position().top;
              const itemHeight = next.outerHeight();
              
              if (itemOffset + itemHeight > dropdownHeight) {
                dropdown.scrollTop(dropdown.scrollTop() + itemHeight);
              }
            }
          }
        }
        // Up arrow
        else if (e.keyCode === 38) {
          e.preventDefault();
          
          if (focused.length === 0) {
            items.last().addClass('focused').css('background-color', '#e0e0ff');
          } else {
            const prev = focused.prev();
            if (prev.length) {
              focused.removeClass('focused').css('background-color', '');
              prev.addClass('focused').css('background-color', '#e0e0ff');
              
              // Scroll into view if needed
              const itemOffset = prev.position().top;
              
              if (itemOffset < 0) {
                dropdown.scrollTop(dropdown.scrollTop() - prev.outerHeight());
              }
            }
          }
        }
        // Enter
        else if (e.keyCode === 13) {
          e.preventDefault();
          
          if (focused.length) {
            const selectedValue = focused.data('value');
            const selectedText = focused.text();
            
            textInput.val(selectedText);
            select.val(selectedValue).trigger('change');
            dropdown.hide();
          } else if (items.length === 1) {
            // If only one item, select it
            const onlyItem = items.first();
            const selectedValue = onlyItem.data('value');
            const selectedText = onlyItem.text();
            
            textInput.val(selectedText);
            select.val(selectedValue).trigger('change');
            dropdown.hide();
          }
        }
        // Escape
        else if (e.keyCode === 27) {
          dropdown.hide();
        }
      });
    });
  }
  
  function setupLocationHandlers() {
    // Handle country change - fetch cities
    $('#building_country_id').on('change', function() {
      console.log("Country changed:", $(this).val());
      const countryId = $(this).val();
      
      if (countryId) {
        // Clear dependent fields
        resetDropdown('#building_city_id');
        resetDropdown('#building_district_id');
        resetDropdown('#building_ward_id');
        
        // Show loading indicator
        $('#building_city_id_autocomplete').css({
          'background-image': 'url("/assets/loading.gif")',
          'background-repeat': 'no-repeat',
          'background-position': 'right 10px center',
          'background-size': '16px'
        }).prop('disabled', true);
        
        // Fetch cities for the selected country
        $.getJSON(`/api/cities/${countryId}`, function(data) {
          console.log("Cities received:", data);
          if (data && data.length > 0) {
            populateDropdown('#building_city_id', data);
          }
          // Remove loading indicator
          $('#building_city_id_autocomplete').css({
            'background-image': ''
          }).prop('disabled', false);
        }).fail(function(jqXHR, textStatus, errorThrown) {
          console.error("Error fetching cities:", textStatus, errorThrown);
          // Remove loading indicator
          $('#building_city_id_autocomplete').css({
            'background-image': ''
          }).prop('disabled', false);
        });
      }
    });
    
    // Handle city change - fetch districts
    $('#building_city_id').on('change', function() {
      console.log("City changed:", $(this).val());
      const cityId = $(this).val();
      
      if (cityId) {
        // Clear dependent fields
        resetDropdown('#building_district_id');
        resetDropdown('#building_ward_id');
        
        // Show loading indicator
        $('#building_district_id_autocomplete').css({
          'background-image': 'url("/assets/loading.gif")',
          'background-repeat': 'no-repeat',
          'background-position': 'right 10px center',
          'background-size': '16px'
        }).prop('disabled', true);
        
        // Fetch districts for the selected city
        $.getJSON(`/api/districts/${cityId}`, function(data) {
          console.log("Districts received:", data);
          if (data && data.length > 0) {
            populateDropdown('#building_district_id', data);
          }
          // Remove loading indicator
          $('#building_district_id_autocomplete').css({
            'background-image': ''
          }).prop('disabled', false);
        }).fail(function(jqXHR, textStatus, errorThrown) {
          console.error("Error fetching districts:", textStatus, errorThrown);
          // Remove loading indicator
          $('#building_district_id_autocomplete').css({
            'background-image': ''
          }).prop('disabled', false);
        });
      }
    });
    
    // Handle district change - fetch wards
    $('#building_district_id').on('change', function() {
      console.log("District changed:", $(this).val());
      const districtId = $(this).val();
      
      if (districtId) {
        // Clear dependent field
        resetDropdown('#building_ward_id');
        
        // Show loading indicator
        $('#building_ward_id_autocomplete').css({
          'background-image': 'url("/assets/loading.gif")',
          'background-repeat': 'no-repeat',
          'background-position': 'right 10px center',
          'background-size': '16px'
        }).prop('disabled', true);
        
        // Fetch wards for the selected district
        $.getJSON(`/api/wards/${districtId}`, function(data) {
          console.log("Wards received:", data);
          if (data && data.length > 0) {
            populateDropdown('#building_ward_id', data);
          }
          // Remove loading indicator
          $('#building_ward_id_autocomplete').css({
            'background-image': ''
          }).prop('disabled', false);
        }).fail(function(jqXHR, textStatus, errorThrown) {
          console.error("Error fetching wards:", textStatus, errorThrown);
          // Remove loading indicator
          $('#building_ward_id_autocomplete').css({
            'background-image': ''
          }).prop('disabled', false);
        });
      }
    });
  }
  
  // Helper function to reset a dropdown
  function resetDropdown(selector) {
    const select = $(selector);
    select.val('').trigger('change');
    
    // Also clear the autocomplete input
    const autocompleteInput = $('#' + select.attr('id') + '_autocomplete');
    autocompleteInput.val('');
  }
  
  // Helper function to populate a dropdown with data
  function populateDropdown(selector, data) {
    const select = $(selector);
    select.empty();
    select.append($('<option></option>').attr('value', '').text(''));
    
    $.each(data, function(index, item) {
      select.append($('<option></option>').attr('value', item.id).text(item.name));
    });
    
    // Update the dropdown UI to show the new options
    const autocompleteInput = $('#' + select.attr('id') + '_autocomplete');
    autocompleteInput.trigger('focus');
  }
  
  // Function to remove diacritics (accents) from Vietnamese text for searching
  function removeDiacritics(str) {
    const diacriticsMap = {
      'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
      'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
      'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
      'đ': 'd',
      'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
      'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
      'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
      'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
      'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
      'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
      'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
      'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
      'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y'
    };

    return str.replace(/[^A-Za-z0-9\s]/g, function(match) {
      return diacriticsMap[match] || match;
    });
  }
});