/*
 * Doclist browser js
 */
function setDocsListLoadingMsg(id, msg) {
  $(id).getElementsByClassName('list')[0].update('<div class="loading"><img src="/images/ajax-loader.gif"> ' + msg + '</div>');
}
function setLoadingMsg(id, msg) {
  $(id).update('<div class="loading"><img src="/images/ajax-loader.gif"> ' + msg + '</div>');
}

document.observe('dom:loaded', function() {
  if ($('documents_data')) {
    $('documents_data').observe('click', function(event) {
      var el = event.element();
      if (el.tagName == 'LI') {
        el.up().childElements().each(function(item) {
          item.removeClassName('selected');
        });
        el.toggleClassName('selected');
      }
    });
  }

  if ($('doc_preview')) {
    $('doc_preview').observe('click', function(event) {
      var el = event.element();
      if (el.tagName == 'LI' && el.up('#contacts')) {
        el.toggleClassName('selected');
        checkbox = el.childElements("input[type='checkbox']")[0];
        checkbox.checked = checkbox.checked ? false : true;
      } else if (el.tagName == 'INPUT' && el.type == 'checkbox') {
        el.up().toggleClassName('selected');
      }
    });
  }
});
