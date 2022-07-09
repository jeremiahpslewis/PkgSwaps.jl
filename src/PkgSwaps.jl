module PkgSwaps

using TOML
using Pkg
using Chain
using DataFrames
using DataFrameMacros
using Scratch

include("Internals.jl")

function recommend(; path = "Project.toml")
    deps_data_toml = TOML.parsefile(path)
    deps_list = collect(keys(deps_data_toml["deps"]))
    deps_list = [[i] for i in deps_list]

    dep_files = Internals.crawl_general_registry()

    dep_dict = Dict(zip(Internals.pkg_name_from_path.(dep_files), Internals.parse_deps_toml.(dep_files)))
    ver_dict = Dict(zip(Internals.pkg_name_from_path.(dep_files), Internals.parse_vers_toml.(dep_files)))

    # TODO: Handle multiple dependency case (where two packages swapped in or out)
    pkg_info = Internals.build_pkg_info(ver_dict, dep_dict)

    pkg_swaps, pkg_analysis = Internals.generate_pkg_analysis(pkg_info, deps_list)

    sample_output = @chain pkg_analysis begin
        @subset(
            (:dropped_dependencies ∈ deps_list)
        )
        @subset(:pkg_count > 1)
        @select(:dropped_dependencies, :new_dependencies, :pkg_count)
    end


    pkg_files = Internals.pull_pkg_links(dep_files)
    
    Internals.print_pkg_swap_output(pkg_files, sample_output)
end


end
