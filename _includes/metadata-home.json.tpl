{
    "page": {
        "title": "Introduction",
        "level": "1.1",
        "depth": 1,
        {% assign posts = site.posts %}

        {% if posts %}
        "next": {
            "title": "{{posts.first.title}}",
            "level": "1.2",
            "depth": 1,
            "path": "{{posts.first.path}}",
            "ref": "{{posts.first.path}}",
            "articles": []
        },
        {% endif %}
        "dir": "ltr"
    },

    {%- include metadata.json.tpl -%}
}