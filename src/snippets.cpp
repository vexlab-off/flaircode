#include "snippets.h"

#include <QRegularExpression>

Snippets::Snippets(QObject *parent) : QObject(parent) {}

// Languages that share a library.
static QString family(const QString &language) {
    if (language == "c")
        return "cpp";
    if (language == "typescript")
        return "javascript";
    if (language == "xml")
        return "html";
    return language;
}

QList<Snippets::Snippet> Snippets::library(const QString &languageIn) {
    const auto language = family(languageIn);
    if (language == "cpp")
        return {
            {"main", "Fonction main", "int main(int argc, char *argv[]) {\n    ${1}\n    return 0;\n}"},
            {"for", "Boucle for avec indice", "for (int ${1:i} = 0; ${1:i} < ${2:count}; ++${1:i}) {\n    $0\n}"},
            {"fore", "Boucle sur une collection", "for (const auto &${1:item} : ${2:items}) {\n    $0\n}"},
            {"if", "Condition", "if (${1:condition}) {\n    $0\n}"},
            {"ife", "Condition avec else", "if (${1:condition}) {\n    $0\n} else {\n}"},
            {"while", "Boucle while", "while (${1:condition}) {\n    $0\n}"},
            {"switch", "Switch", "switch (${1:value}) {\ncase ${2:0}:\n    $0\n    break;\ndefault:\n    break;\n}"},
            {"class", "Classe", "class ${1:Name} {\npublic:\n    ${1:Name}();\n    ~${1:Name}();\n\nprivate:\n    $0\n};"},
            {"struct", "Structure", "struct ${1:Name} {\n    $0\n};"},
            {"qobject", "Classe QObject", "class ${1:Name} : public QObject {\n    Q_OBJECT\n\npublic:\n    explicit ${1:Name}(QObject *parent = nullptr);\n\nsignals:\n\nprivate:\n    $0\n};"},
            {"qprop", "Propriété Qt", "Q_PROPERTY(${1:QString} ${2:name} READ ${2:name} WRITE set${3:Name} NOTIFY ${2:name}Changed)"},
            {"inc", "#include <…>", "#include <${1:QString}>"},
            {"incl", "#include \"…\"", "#include \"${1:file.h}\""},
            {"once", "Garde d'en-tête", "#pragma once\n\n$0"},
            {"lambda", "Lambda", "[${1:&}](${2}) {\n    $0\n}"},
            {"try", "try / catch", "try {\n    $0\n} catch (const std::exception &${1:error}) {\n}"},
            {"cout", "Afficher (std::cout)", "std::cout << ${1:value} << std::endl;"},
            {"qdebug", "Afficher (qDebug)", "qDebug() << ${1:value};"},
        };
    if (language == "javascript")
        return {
            {"fn", "Fonction", "function ${1:name}(${2}) {\n    $0\n}"},
            {"afn", "Fonction fléchée", "const ${1:name} = (${2}) => {\n    $0\n};"},
            {"asyncfn", "Fonction async", "async function ${1:name}(${2}) {\n    $0\n}"},
            {"for", "Boucle for", "for (let ${1:i} = 0; ${1:i} < ${2:array}.length; ${1:i}++) {\n    $0\n}"},
            {"forof", "Boucle for…of", "for (const ${1:item} of ${2:items}) {\n    $0\n}"},
            {"foreach", "forEach", "${1:items}.forEach((${2:item}) => {\n    $0\n});"},
            {"if", "Condition", "if (${1:condition}) {\n    $0\n}"},
            {"ife", "Condition avec else", "if (${1:condition}) {\n    $0\n} else {\n}"},
            {"class", "Classe", "class ${1:Name} {\n    constructor(${2}) {\n        $0\n    }\n}"},
            {"imp", "Import", "import { ${2:thing} } from \"${1:module}\";"},
            {"exp", "Export par défaut", "export default ${1:name};"},
            {"log", "console.log", "console.log(${1:value});"},
            {"try", "try / catch", "try {\n    $0\n} catch (${1:error}) {\n    console.error(${1:error});\n}"},
            {"fetch", "Requête fetch", "const response = await fetch(\"${1:url}\");\nconst data = await response.json();\n$0"},
            {"timeout", "setTimeout", "setTimeout(() => {\n    $0\n}, ${1:1000});"},
            {"listener", "Écouteur d'événement", "${1:element}.addEventListener(\"${2:click}\", (event) => {\n    $0\n});"},
            {"qs", "querySelector", "document.querySelector(\"${1:selector}\")"},
        };
    if (language == "python")
        return {
            {"def", "Fonction", "def ${1:name}(${2}):\n    ${0:pass}"},
            {"adef", "Fonction async", "async def ${1:name}(${2}):\n    ${0:pass}"},
            {"class", "Classe", "class ${1:Name}:\n    def __init__(self${2}):\n        ${0:pass}"},
            {"dataclass", "Dataclass", "from dataclasses import dataclass\n\n\n@dataclass\nclass ${1:Name}:\n    ${2:field}: ${3:str}"},
            {"main", "Point d'entrée", "def main():\n    ${0:pass}\n\n\nif __name__ == \"__main__\":\n    main()"},
            {"for", "Boucle for", "for ${1:item} in ${2:items}:\n    ${0:pass}"},
            {"forr", "Boucle sur un intervalle", "for ${1:i} in range(${2:10}):\n    ${0:pass}"},
            {"if", "Condition", "if ${1:condition}:\n    ${0:pass}"},
            {"ife", "Condition avec else", "if ${1:condition}:\n    ${0:pass}\nelse:\n    pass"},
            {"while", "Boucle while", "while ${1:condition}:\n    ${0:pass}"},
            {"try", "try / except", "try:\n    ${0:pass}\nexcept ${1:Exception} as ${2:error}:\n    print(${2:error})"},
            {"with", "Ouvrir un fichier", "with open(\"${1:file.txt}\", \"${2:r}\", encoding=\"utf-8\") as ${3:f}:\n    ${0:content = f.read()}"},
            {"lc", "Compréhension de liste", "[${1:x} for ${1:x} in ${2:items}]"},
            {"pr", "print", "print(${1:value})"},
            {"imp", "Import", "from ${1:module} import ${2:name}"},
        };
    if (language == "qml")
        return {
            {"item", "Item", "Item {\n    id: ${1:root}\n    $0\n}"},
            {"rect", "Rectangle", "Rectangle {\n    width: ${1:100}\n    height: ${2:100}\n    color: \"${3:#ff8a3d}\"\n    $0\n}"},
            {"text", "Text", "Text {\n    text: \"${1:Bonjour}\"\n    color: ${2:\"white\"}\n}"},
            {"row", "RowLayout", "RowLayout {\n    spacing: ${1:8}\n    $0\n}"},
            {"col", "ColumnLayout", "ColumnLayout {\n    spacing: ${1:8}\n    $0\n}"},
            {"ma", "MouseArea", "MouseArea {\n    anchors.fill: parent\n    onClicked: ${1}\n}"},
            {"prop", "Propriété", "property ${1:int} ${2:name}: ${3:0}"},
            {"sig", "Signal", "signal ${1:name}(${2})"},
            {"fn", "Fonction", "function ${1:name}(${2}) {\n    $0\n}"},
            {"conn", "Connections", "Connections {\n    target: ${1:object}\n    function on${2:Signal}() {\n        $0\n    }\n}"},
            {"rep", "Repeater", "Repeater {\n    model: ${1:items}\n    delegate: ${2:Text} {\n        required property var modelData\n        $0\n    }\n}"},
            {"list", "ListView", "ListView {\n    anchors.fill: parent\n    model: ${1:items}\n    delegate: Text {\n        required property var modelData\n        text: modelData\n    }\n}"},
            {"anim", "Animation de propriété", "Behavior on ${1:opacity} {\n    NumberAnimation { duration: ${2:200}; easing.type: Easing.OutCubic }\n}"},
            {"sc", "Raccourci clavier", "Shortcut {\n    sequence: \"${1:Ctrl+S}\"\n    onActivated: ${2}\n}"},
            {"timer", "Timer", "Timer {\n    interval: ${1:1000}\n    running: true\n    onTriggered: ${2}\n}"},
        };
    if (language == "html")
        return {
            {"html", "Page HTML complète", "<!doctype html>\n<html lang=\"fr\">\n<head>\n    <meta charset=\"utf-8\">\n    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n    <title>${1:Titre}</title>\n    <link rel=\"stylesheet\" href=\"${2:style.css}\">\n</head>\n<body>\n    $0\n</body>\n</html>"},
            {"div", "div", "<div class=\"${1:classe}\">\n    $0\n</div>"},
            {"a", "Lien", "<a href=\"${1:#}\">${2:texte}</a>"},
            {"img", "Image", "<img src=\"${1:image.png}\" alt=\"${2:description}\">"},
            {"btn", "Bouton", "<button type=\"button\">${1:Valider}</button>"},
            {"ul", "Liste", "<ul>\n    <li>${1}</li>\n</ul>"},
            {"form", "Formulaire", "<form action=\"${1:#}\" method=\"${2:post}\">\n    <label for=\"${3:nom}\">${4:Nom}</label>\n    <input id=\"${3:nom}\" name=\"${3:nom}\" type=\"text\">\n    <button type=\"submit\">Envoyer</button>\n</form>"},
            {"input", "Champ", "<input type=\"${1:text}\" name=\"${2:nom}\" placeholder=\"${3}\">"},
            {"script", "Script", "<script src=\"${1:app.js}\"></script>"},
            {"style", "Feuille de style", "<link rel=\"stylesheet\" href=\"${1:style.css}\">"},
            {"section", "Section", "<section>\n    <h2>${1:Titre}</h2>\n    $0\n</section>"},
        };
    if (language == "css")
        return {
            {"flex", "Flexbox", "display: flex;\nalign-items: ${1:center};\njustify-content: ${2:center};\ngap: ${3:8px};"},
            {"grid", "Grille", "display: grid;\ngrid-template-columns: repeat(${1:auto-fit}, minmax(${2:200px}, 1fr));\ngap: ${3:16px};"},
            {"center", "Centrer", "display: grid;\nplace-items: center;"},
            {"media", "Media query", "@media (max-width: ${1:768px}) {\n    $0\n}"},
            {"dark", "Mode sombre", "@media (prefers-color-scheme: dark) {\n    $0\n}"},
            {"var", "Variable CSS", "--${1:nom}: ${2:valeur};"},
            {"tr", "Transition", "transition: ${1:all} ${2:200ms} ${3:ease-out};"},
            {"kf", "Animation", "@keyframes ${1:nom} {\n    from { ${2:opacity: 0;} }\n    to { ${3:opacity: 1;} }\n}"},
            {"font", "Police importée", "@font-face {\n    font-family: \"${1:Nom}\";\n    src: url(\"${2:font.woff2}\") format(\"woff2\");\n}"},
        };
    if (language == "shell")
        return {
            {"sh", "En-tête de script", "#!/bin/sh\nset -eu\n\n$0"},
            {"bash", "En-tête bash strict", "#!/usr/bin/env bash\nset -euo pipefail\n\n$0"},
            {"if", "Condition", "if [ ${1:condition} ]; then\n    $0\nfi"},
            {"iff", "Si le fichier existe", "if [ -f \"${1:fichier}\" ]; then\n    $0\nfi"},
            {"for", "Boucle for", "for ${1:item} in ${2:liste}; do\n    $0\ndone"},
            {"while", "Lire ligne par ligne", "while IFS= read -r ${1:line}; do\n    $0\ndone < \"${2:fichier}\""},
            {"fn", "Fonction", "${1:nom}() {\n    $0\n}"},
            {"case", "case", "case \"${1:\\$1}\" in\n    ${2:motif})\n        $0\n        ;;\n    *)\n        ;;\nesac"},
            {"args", "Vérifier les arguments", "if [ \"\\$#\" -lt ${1:1} ]; then\n    echo \"usage: ${2:script} ${3:argument}\" >&2\n    exit 1\nfi"},
        };
    if (language == "rust")
        return {
            {"fn", "Fonction", "fn ${1:name}(${2}) -> ${3:()} {\n    $0\n}"},
            {"main", "main", "fn main() {\n    $0\n}"},
            {"struct", "Structure", "#[derive(Debug, Clone)]\nstruct ${1:Name} {\n    ${2:field}: ${3:String},\n}"},
            {"impl", "Bloc impl", "impl ${1:Name} {\n    $0\n}"},
            {"enum", "Énumération", "#[derive(Debug)]\nenum ${1:Name} {\n    ${2:Variant},\n}"},
            {"match", "match", "match ${1:value} {\n    ${2:pattern} => $0,\n    _ => {}\n}"},
            {"for", "Boucle for", "for ${1:item} in ${2:items} {\n    $0\n}"},
            {"test", "Module de tests", "#[cfg(test)]\nmod tests {\n    use super::*;\n\n    #[test]\n    fn ${1:it_works}() {\n        $0\n    }\n}"},
            {"pr", "println!", "println!(\"{${1}}\", ${2:value});"},
        };
    if (language == "go")
        return {
            {"main", "Programme", "package main\n\nimport \"fmt\"\n\nfunc main() {\n\t$0\n}"},
            {"fn", "Fonction", "func ${1:name}(${2}) ${3:error} {\n\t$0\n}"},
            {"iferr", "Gestion d'erreur", "if err != nil {\n\treturn ${1:err}\n}"},
            {"for", "Boucle range", "for ${1:_}, ${2:item} := range ${3:items} {\n\t$0\n}"},
            {"struct", "Structure", "type ${1:Name} struct {\n\t${2:Field} ${3:string}\n}"},
            {"pr", "fmt.Println", "fmt.Println(${1:value})"},
        };
    if (language == "markdown")
        return {
            {"h1", "Titre", "# ${1:Titre}"},
            {"h2", "Sous-titre", "## ${1:Sous-titre}"},
            {"code", "Bloc de code", "```${1:bash}\n$0\n```"},
            {"link", "Lien", "[${1:texte}](${2:https://})"},
            {"img", "Image", "![${1:description}](${2:image.png})"},
            {"table", "Tableau", "| ${1:Colonne} | ${2:Colonne} |\n|---|---|\n| $0 |  |"},
            {"todo", "Liste de tâches", "- [ ] ${1:tâche}"},
            {"readme", "Squelette de README", "# ${1:Projet}\n\n${2:Ce que fait le projet, en une phrase.}\n\n## Installation\n\n```sh\n$0\n```\n\n## Utilisation\n\n## Licence\n\nMIT"},
        };
    if (language == "json")
        return {{"obj", "Objet", "{\n    \"${1:clé}\": ${2:\"valeur\"}\n}"}, {"arr", "Tableau", "[\n    $0\n]"}};
    return {};
}

QVariantMap Snippets::render(const QString &body) {
    // Expand ${n:text} to text and ${n}/$n/$0 to nothing, remembering where the
    // first placeholder (lowest number above 0) and $0 land.
    static const QRegularExpression token(R"(\$\{(\d+)(?::((?:[^}\\]|\\.)*))?\}|\$(\d+))");
    QString out;
    int last = 0, bestNumber = INT_MAX, selStart = -1, selEnd = -1, finalCursor = -1;
    auto it = token.globalMatch(body);
    while (it.hasNext()) {
        const auto m = it.next();
        out += QString(body.mid(last, m.capturedStart() - last)).replace("\\$", "$");
        const int number = (m.captured(1).isEmpty() ? m.captured(3) : m.captured(1)).toInt();
        const auto text = QString(m.captured(2)).replace("\\$", "$").replace("\\}", "}");
        const int start = int(out.size());
        out += text;
        if (number == 0) {
            finalCursor = start;
        } else if (number < bestNumber) {
            bestNumber = number;
            selStart = start;
            selEnd = start + int(text.size());
        }
        last = int(m.capturedEnd());
    }
    out += QString(body.mid(last)).replace("\\$", "$");
    if (selStart < 0) {
        selStart = selEnd = finalCursor >= 0 ? finalCursor : int(out.size());
    }
    return {{"text", out}, {"selectionStart", selStart}, {"selectionEnd", selEnd}};
}

QVariantMap Snippets::expand(const QString &language, const QString &prefix) const {
    for (const auto &s : library(language))
        if (s.prefix == prefix)
            return render(s.body);
    return {};
}

QVariantList Snippets::forLanguage(const QString &language) const {
    QVariantList list;
    for (const auto &s : library(language))
        list.append(QVariantMap{{"prefix", s.prefix}, {"description", s.description},
                                {"preview", render(s.body).value("text")}});
    return list;
}

QStringList Snippets::languages() const {
    return {"cpp", "javascript", "python", "qml", "html", "css", "shell", "rust", "go", "markdown", "json"};
}
