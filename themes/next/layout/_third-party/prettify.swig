
{% if theme.custom_highlight_theme %}
  <link rel="stylesheet" href="/lib/prettify/themes/{{ theme.custom_highlight_theme }}.min.css" type="text/css">
{% else %}
    <link rel="stylesheet" href="/lib/prettify/themes/prettify.css" type="text/css">
{% endif %}
<script src="/lib/prettify/prettify.js"></script>

{# 加入copy按钮#}
<script src="https://cdnjs.cloudflare.com/ajax/libs/clipboard.js/2.0.0/clipboard.min.js"></script>

<script type="text/javascript">
$(window).load(function(){
  // 设置prettify
  $('pre').addClass('prettyprint linenums');
   prettyPrint();
  // 定义copy函数
  var initCopyCode = function(){
    var copyHtml = '';
    copyHtml += '<button class="btn-copy" data-clipboard-snippet="">';
    copyHtml += '  <i class="fa fa-globe"></i><span>copy</span>';
    copyHtml += '</button>';
    $(".highlight .code pre").before(copyHtml);
    new ClipboardJS('.btn-copy', {
        target: function(trigger) {
            return trigger.nextElementSibling;
        }
    });
  }
  initCopyCode();
 })
</script>

{# 加入 highlight代码高亮#}
{#
<link rel="stylesheet" href="//cdn.bootcss.com/highlight.js/9.12.0/styles/atom-one-dark.min.css">
<script src="//cdn.bootcss.com/highlight.js/9.2.0/highlight.min.js">
</script>
<script>
    $(function() {
    hljs.initHighlighting();

  });
</script>
#}
