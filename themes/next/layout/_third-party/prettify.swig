
{% if theme.custom_highlight_theme %}
  <link rel="stylesheet" href="/lib/prettify/themes/{{ theme.custom_highlight_theme }}.min.css" type="text/css">
{% else %}
    <link rel="stylesheet" href="/lib/prettify/themes/prettify.css" type="text/css">
{% endif %}
<script src="/lib/prettify/prettify.js"></script>
<script type="text/javascript">
$(window).load(function(){
  // 设置prettify
  $('pre').addClass('prettyprint linenums');
   prettyPrint();
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
