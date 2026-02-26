function mkch
    set project_dir ~/Documents/projects/chinese_md_to_anki/ # Your project path
    pushd $project_dir
    uv run python -m src.main $argv
    popd
end
