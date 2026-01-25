function mkch
    set project_dir ~/Documents/03_projects/Chinese # Your project path
    pushd $project_dir
    uv run python -m src.main $argv
    popd
end
