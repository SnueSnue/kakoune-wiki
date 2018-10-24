declare-option -docstring %{ Path to wiki directory } str wiki_path

# program that outputs relative path given two absolute as params
declare-option -hidden str wiki_relative_path_program %{ perl -e 'use File::Spec; print File::Spec->abs2rel(@ARGV) . "\n"' }


define-command -hidden -params 1 wiki_setup %{
    evaluate-commands %sh{
        echo "set-option global wiki_path $1"
        echo "hook global BufCreate $1/.+\.md %{ wiki_enable }"
    }
}

define-command wiki -params 1  \
-docstring %{ wiki [file.md]: Edit or create wiki page } \
-shell-candidates %{ cd $kak_opt_wiki_path; find . -type f -name '*.md' | sed -e 's/^\.\///' }  \
%{ evaluate-commands %sh{
    dir="$(dirname $1)"
    base="$(basename $1 .md)" #no extension
    normalized="$base.md"
    path="$dir/$normalized"
    if [ ! -e "$kak_opt_wiki_path/$path" ]; then
        echo "wiki_new_page \"$dir/$base\""
    fi
    echo "edit ""$kak_opt_wiki_path/$path"""
}}

define-command wiki_enable %{
    add-highlighter buffer/wiki group
    add-highlighter buffer/wiki/tag regex '\B@\S+' 0:link
    add-highlighter buffer/wiki/link regex '\[\w+\]' 0:link
    hook buffer InsertKey '<ret>' -group wiki %{
        evaluate-commands %{ try %{ 
            execute-keys -draft %{
                2h<a-b><a-k>\A@\w+<ret>
                :wiki_expand_tag<ret>
            }
            execute-keys <esc>hi
        } }
    }
    hook buffer NormalKey '<ret>' -group wiki %{
        try %{ wiki_follow_link }
        try %{ wiki_toggle_checkbox }
    }
}

define-command wiki_disable %{
    remove-highlighter buffer/wiki
    remove-hooks buffer wiki
}

define-command wiki_expand_tag \
-docstring %{ Expands tag from @filename form to [filename](filename.md)
Creates empty markdown file in wiki_path if not exist. Selection must be
somewhere on @tag and @tag should not contain extension } %{
    evaluate-commands %sh{
        this="$kak_buffile"
        tag=$(echo $kak_selection | sed -e 's/^\@//')
        other="$kak_opt_wiki_path/$tag.md"
        relative=$(eval "$kak_opt_wiki_relative_path_program" "$other" $(dirname "$this"))
        # sanity chceck
        echo "execute-keys  -draft '<a-k>\A@[^@]+<ret>'"
        echo "execute-keys \"c[$tag]($relative)<esc>\""
        echo "wiki_new_page \"$tag\""
    }
}

define-command -params 1 -hidden \
-docstring %{ wiki_new_page [name]: create new wiki page in wiki_path if not exists } \
wiki_new_page %{
    nop %sh{
        dir="$(dirname $kak_opt_wiki_path/$1.md)"
        mkdir -p "$dir"
        touch "$kak_opt_wiki_path/$1.md"
    }
}

define-command wiki_follow_link \
-docstring %{ Follow markdown link and open file if exists } %{
    evaluate-commands %{ 
        execute-keys %{
            <esc><a-a>c\[,\)<ret><a-:>
            <a-i>b
        }
        evaluate-commands -try-client %opt{jumpclient} edit -existing %{ %sh{ echo $kak_selection }}
        try %{  focus %opt{jumpclient} }
    }
}

define-command wiki_toggle_checkbox \
-docstring "Toggle markdown checkbox in current line" %{
    try %{
        try %{
            execute-keys -draft %{
                <esc><space>;xs-\s\[\s\]<ret><a-i>[rX
        }} catch %{
            execute-keys -draft %{
                <esc><space>;xs-\s\[X\]<ret><a-i>[r<space>
    }}}
}