function append_diary
    set file $argv[1]

    if test -z "$file"
        echo "Usage: append_diary <file>"
        return 1
    end

    set today (date "+%d")

    printf "\n# %s\n## Learn\n1. \n## Workflow\n1. \n## Config\n1. \n" $today >>$file
end
