module PkgSwaps

using TOML
using ReadableRegex
using Pkg
using Base: UUID, SHA1
using Chain
import Pkg.Versions: VersionRange
import Pkg.Registry: VersionInfo
using DataFrames
using DataFrameMacros
using ShiftedArrays
using Term

export recommend

function download_registry()
    if !("General" in readdir())
        run(`git clone https://github.com/JuliaRegistries/General.git`)
    end

    deps_toml_regex = "General/" * exactly(1, LETTER) *
                        "/" * one_or_more(char_not_in("/")) *
                        "/Deps.toml"
    dep_files = []
    for (root, dirs, files) in walkdir("General")
        for file in files
                full_path = joinpath(root, file)
            if match(deps_toml_regex, full_path) != nothing
                push!(dep_files, full_path)
            end
        end
    end

    return dep_files
end


function parse_deps_toml(dep_path)
    deps_data_toml= TOML.parsefile(dep_path)
    # Borrowed from here: https://github.com/JuliaLang/Pkg.jl/blob/503f31f64bcda5a60f0b3676730b689ff1f91aa9/src/Registry/registry_instance.jl#L172
    deps_data_toml = convert(Dict{String, Dict{String, String}}, deps_data_toml)
    deps = Dict{VersionRange, Dict{String, UUID}}()
    for (v, data) in deps_data_toml
        vr = VersionRange(v)
        d = Dict{String, UUID}(dep => UUID(uuid) for (dep, uuid) in data)
        deps[vr] = d
    end
    return deps
end

function parse_vers_toml(dep_path)
    # Borrowed from here: https://github.com/JuliaLang/Pkg.jl/blob/503f31f64bcda5a60f0b3676730b689ff1f91aa9/src/Registry/registry_instance.jl#L154

    dep_path = dirname(dep_path) * "/Versions.toml"
    d_v= TOML.parsefile(dep_path)
    version_info = Dict{VersionNumber, VersionInfo}(VersionNumber(k) =>
        VersionInfo(SHA1(v["git-tree-sha1"]::String), get(v, "yanked", false)::Bool) 	for (k, v) in d_v)
    
    return version_info
end

pkg_name_from_path = x -> split(x, '/')[3]

function build_pkg_info(ver_dict)
    pkg_info = []
    for pkg in keys(ver_dict)
        for ver in ver_dict[pkg]
            for dep in dep_dict[pkg]
                if ver[1] in dep[1]
                    push!(pkg_info, (pkg, ver[1], collect(keys(dep[2]))[1]))
                end
            end
        end
    end
    return pkg_info
end


function generate_pkg_analysis(pkg_info)
    pkg_info_df = DataFrame(pkg_info)
    rename!(pkg_info_df, ["package", "version", "dependency"])

    pkg_analysis = @chain pkg_info_df begin
        @groupby(:package, :version)
        @combine(:dependencies = join(:dependency, ","))
        @transform(:dependencies = split.(:dependencies, ","))
        @sort(:package, :version)
        @groupby(:package)
        @transform(:dropped_dependencies = @c lag(:dependencies, 1))
        @transform(:new_dependencies = @m sort(setdiff(:dependencies, :dropped_dependencies)))
        @transform(:dropped_dependencies = @m sort(setdiff(:dropped_dependencies, :dependencies)))
        @transform!(@subset((:new_dependencies == []) | (:new_dependencies === missing)), :new_dependencies = nothing)
        @transform!(@subset((:dropped_dependencies == []) | (:dropped_dependencies === missing)), :dropped_dependencies = nothing)
        @groupby(:new_dependencies, :dropped_dependencies)
        @combine(:pkg_count = length(:package), :packages = join(:package, ","))
        @sort(-:pkg_count)
        @subset((:new_dependencies != nothing) &
                (:dropped_dependencies != nothing) &
                (:new_dependencies != ["Test"]) &
                (:dropped_dependencies != ["Test"])
        )
        @transform(:difflist = sort([:new_dependencies; :dropped_dependencies]))
    end

    dupes = pkg_analysis[!, :difflist] .∈ (pkg_analysis[nonunique(pkg_analysis, :difflist), :difflist], )

    pkg_swaps = sort(unique(vcat(pkg_analysis[!, :new_dependencies]..., pkg_analysis[!, :dropped_dependencies]...)))
    return pkg_swaps
end

function pull_pkg_links(dep_files)
    pkg_toml_regex = "General/" * exactly(1, LETTER) *
                        "/" * one_or_more(char_not_in("/")) *
                        "/Package.toml"
    pkg_files = []
    for (root, dirs, files) in walkdir("General")
        for file in files
                full_path = joinpath(root, file)
            if match(pkg_toml_regex, full_path) != nothing
                push!(pkg_files, full_path)
            end
        end
    end
    pkg_files
end

function parse_pkg_toml(pkg_path)
    # Borrowed from here: https://github.com/JuliaLang/Pkg.jl/blob/503f31f64bcda5a60f0b3676730b689ff1f91aa9/src/Registry/registry_instance.jl#L154
    d_v = TOML.parsefile(pkg_path)	
    return d_v
end

function print_pkg_swap_output(pkg_files, sample_output)
    df_pkg = @chain pkg_files begin
        parse_pkg_toml.()
        hcat
        DataFrame(:auto)
        @select(:pkg = :x1["name"], :repo = :x1["repo"])
    end

    println(
        @bold("Suggested Package Swaps:")
    )
    println()
    
    dep_out = ""
    for r in eachrow(sample_output)
        if dep_out != r[:dropped_dependencies][1]
            if dep_out != ""
                println()
            end
        end
        dep_out = r[:dropped_dependencies][1]
        dep_in = r[:new_dependencies][1]

        dep_out_link = @chain df_pkg @subset(:pkg == dep_out) @select(:repo) _[!, 1][1]
        dep_in_link = @chain df_pkg @subset(:pkg == dep_in) @select(:repo) _[!, 1][1]

        dep_out_fmt = Term.creat_link(dep_out_link, String(dep_out))
        dep_in_fmt = Term.creat_link(dep_in_link, String(dep_in))
        println(
            @italic(@red(dep_out_fmt)) * " ↗️ " * @bold(@green(dep_in_fmt))
        )
    end
end

function recommend(path)
    deps_data_toml = TOML.parsefile(path)
    deps_list = collect(keys(deps_data_toml["deps"]))
    deps_list = [[i] for i in deps_list]

    dep_files = download_registry()

    dep_dict = Dict(zip(pkg_name_from_path.(dep_files), parse_deps_toml.(dep_files)))
    ver_dict = Dict(zip(pkg_name_from_path.(dep_files), parse_vers_toml.(dep_files)))

    pkg_info = build_pkg_info(ver_dict)

    pkg_swaps = generate_pkg_analysis(pkg_info)

    sample_output = @chain pkg_swaps begin
        @subset(
            (:dropped_dependencies ∈ deps_list)
        )
        @subset(:pkg_count > 1)
        @select(:dropped_dependencies, :new_dependencies)
    end


    pkg_files = pull_pkg_links(dep_files)
    
    print_pkg_swap_output(pkg_files, sample_output)
end


end
