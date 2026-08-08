using Documenter, FerriteTikz

const liveserver = "liveserver" in ARGS

if liveserver
    using Revise
    Revise.revise()
end

DocMeta.setdocmeta!(FerriteTikz, :DocTestSetup, :(using FerriteTikz); recursive = true)

makedocs(;
    format = Documenter.HTML(;
        canonical = "https://henrij22.github.io/FerriteTikz.jl/stable",
        collapselevel = 1,
        assets = String[],
    ),
    repo = Documenter.Remotes.GitHub("henrij22", "FerriteTikz.jl"),
    modules = [FerriteTikz],
    sitename = "FerriteTikz.jl",
    warnonly = true, checkdocs = :none,
    pages = [
        "Home" => "index.md",
        "Tutorials" => [
            "Tutorials overview" => "tutorials/index.md",
            "tutorials/wireframe.md",
            "tutorials/cellsets.md",
            "tutorials/deformed.md",
        ],
        "API Reference" => "api_reference.md",
        "Developer documentation" => "developer.md",
    ],
)

if !liveserver
    deploydocs(;
        repo = "github.com/henrij22/FerriteTikz.jl.git",
        push_preview = true,
        versions = [
            "stable" => "v^",
            "dev" => "dev",
        ],
    )
end
