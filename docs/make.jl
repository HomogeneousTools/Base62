using Documenter, Base62

DocMeta.setdocmeta!(Base62, :DocTestSetup, :(using Base62); recursive=true)

makedocs(;
    modules=[Base62],
    authors="HomogeneousTools",
    repo="https://github.com/HomogeneousTools/Base62.jl/blob/{commit}{path}#{line}",
    sitename="Base62.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", nothing) == "true",
        canonical="https://homogeneoustools.github.io/Base62.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
    checkdocs=:none,
)

deploydocs(;
    repo="github.com/HomogeneousTools/Base62.jl",
    devbranch="main",
    push_preview=false,
)
