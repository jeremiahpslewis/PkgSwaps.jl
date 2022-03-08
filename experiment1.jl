### A Pluto.jl notebook ###
# v0.18.0

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ c6c4c3c8-0627-45d6-9447-6e3df722fb06
begin
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
	using PlutoUI
	using CommonMark

	if !("General" in readdir())
		run(`git clone https://github.com/JuliaRegistries/General.git`)
	end
end

# ╔═╡ c9007dce-1da2-4cbf-821d-3b3cba6bb2eb
cm"# Package Swaps: Julia Package Economy Preliminary Analysis"

# ╔═╡ 424b80c0-5c5d-4ff2-8285-9f08f2f5d62e
begin
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
	
	dep_files
end

# ╔═╡ a61c0650-c73f-4ee2-87de-f9fe5e49006a
pkg_name_from_path = x -> split(x, '/')[3]

# ╔═╡ 3df77bf7-c364-4e27-bc06-a44d57d6db50


# ╔═╡ 667f1492-4549-48b7-83f7-792628135594
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

# ╔═╡ 0da5cc42-99e8-418c-95ca-93aa26c1e796
function parse_vers_toml(dep_path)
	# Borrowed from here: https://github.com/JuliaLang/Pkg.jl/blob/503f31f64bcda5a60f0b3676730b689ff1f91aa9/src/Registry/registry_instance.jl#L154

	dep_path = dirname(dep_path) * "/Versions.toml"
	d_v= TOML.parsefile(dep_path)
    version_info = Dict{VersionNumber, VersionInfo}(VersionNumber(k) =>
        VersionInfo(SHA1(v["git-tree-sha1"]::String), get(v, "yanked", false)::Bool) for (k, v) in d_v)
	
	return version_info
end

# ╔═╡ 2851f582-a3dc-48d2-b74a-8a2d013c9a43
d_v = dirname("General/Z/Zomato/Deps.toml") * "/Versions.toml"

# ╔═╡ 2b791542-ea24-42ac-87cb-c9dcc47a84a5
dep_dict = Dict(zip(pkg_name_from_path.(dep_files), parse_deps_toml.(dep_files)))

# ╔═╡ b6dbb822-a951-42cd-a2f1-74e7cd79f250
ver_dict = Dict(zip(pkg_name_from_path.(dep_files), parse_vers_toml.(dep_files)))

# ╔═╡ 4e77e29f-80aa-48ae-a034-fe29d1d8dcd1
dep_dict["FastLapackInterface"]

# ╔═╡ 58907d25-a0b5-431b-90be-259cae9bc6f1
begin
	# keys(ver_dict["FastLapackInterface"])
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
end

# ╔═╡ 98d1cdda-0203-429c-9a27-de5605f04086
begin
	pkg_info_df = DataFrame(pkg_info)
	rename!(pkg_info_df, ["package", "version", "dependency"])
end

# ╔═╡ 056ec327-0108-4d19-a081-eb013af79ed9
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
	@subset((:new_dependencies != nothing) & (:dropped_dependencies != nothing))
	@transform(:difflist = sort([:new_dependencies; :dropped_dependencies]))
end

# ╔═╡ 4f1297e0-9a1b-4f1a-917e-f36dbae1a95e
begin
	dupes = pkg_analysis[!, :difflist] .∈ (pkg_analysis[nonunique(pkg_analysis, :difflist), :difflist], )
	
	@chain pkg_analysis[dupes, :] @sort(-:pkg_count) @select(:difflist, :packages, :pkg_count, :new_dependencies, :dropped_dependencies)
end

# ╔═╡ 12d5db00-8d44-48d5-ac94-6a067106c3fc
pkg_swaps = sort(unique(vcat(pkg_analysis[!, :new_dependencies]..., pkg_analysis[!, :dropped_dependencies]...)))

# ╔═╡ 812a3dbb-90dc-43a9-89ca-e38b88919057
@bind pkg_selected Select(pkg_swaps)

# ╔═╡ b48d27c0-501b-438a-b2e9-f150bcaf876e
@chain pkg_analysis @subset((pkg_selected ∈ :new_dependencies) | (pkg_selected ∈ :dropped_dependencies)) @select(:new_dependencies, :dropped_dependencies, :pkg_count, :packages)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Chain = "8be319e6-bccf-4806-a6f7-6fae938471bc"
CommonMark = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
DataFrameMacros = "75880514-38bc-4a95-a458-c2aea5a3a702"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Pkg = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
ReadableRegex = "cbbcb084-453d-4c4c-b292-e315607ba6a4"
ShiftedArrays = "1277b4bf-5013-50f5-be3d-901d8477a67a"
TOML = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[compat]
Chain = "~0.4.10"
CommonMark = "~0.8.6"
DataFrameMacros = "~0.2.1"
DataFrames = "~1.3.2"
PlutoUI = "~0.7.37"
ReadableRegex = "~0.3.2"
ShiftedArrays = "~1.0.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.8.0-beta1"
manifest_format = "2.0"
project_hash = "18afafeefceeb1f2dd2bd49ccc36bfe5724c11d6"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Chain]]
git-tree-sha1 = "339237319ef4712e6e5df7758d0bccddf5c237d9"
uuid = "8be319e6-bccf-4806-a6f7-6fae938471bc"
version = "0.4.10"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[deps.CommonMark]]
deps = ["Crayons", "JSON", "URIs"]
git-tree-sha1 = "4cd7063c9bdebdbd55ede1af70f3c2f48fab4215"
uuid = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
version = "0.8.6"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "96b0bc6c52df76506efc8a441c6cf1adcb1babc4"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.42.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "0.5.0+0"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[deps.DataFrameMacros]]
deps = ["DataFrames"]
git-tree-sha1 = "cff70817ef73acb9882b6c9b163914e19fad84a9"
uuid = "75880514-38bc-4a95-a458-c2aea5a3a702"
version = "0.2.1"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "ae02104e835f219b8930c7664b8012c93475c340"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.3.2"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "3daef5523dd2e769dad2365274f760ff5f282c7d"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.11"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
git-tree-sha1 = "2b078b5a615c6c0396c77810d92ee8c6f470d238"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.3"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.81.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.2.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.17+2"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "85b5da0fa43588c75bb1ff986493443f821c70b7"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.2.3"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.8.0"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "bf0a1121af131d9974241ba53f601211e9303a9e"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.37"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "db3a23166af8aebf4db5ef87ac5b00d36eb771e2"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "dfb54c4e414caa595a1f2ed759b160f5a3ddcba5"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.3.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.ReadableRegex]]
git-tree-sha1 = "befcfa33f50688319571a770be4a55114b71d70a"
uuid = "cbbcb084-453d-4c4c-b292-e315607ba6a4"
version = "0.3.2"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.ShiftedArrays]]
git-tree-sha1 = "22395afdcf37d6709a5a0766cc4a5ca52cb85ea0"
uuid = "1277b4bf-5013-50f5-be3d-901d8477a67a"
version = "1.0.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.0"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "5ce79ce186cc678bbb5c5681ca3379d1ddae11a1"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.7.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.12+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.0.1+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.41.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "16.2.1+1"
"""

# ╔═╡ Cell order:
# ╠═c6c4c3c8-0627-45d6-9447-6e3df722fb06
# ╠═c9007dce-1da2-4cbf-821d-3b3cba6bb2eb
# ╠═424b80c0-5c5d-4ff2-8285-9f08f2f5d62e
# ╠═a61c0650-c73f-4ee2-87de-f9fe5e49006a
# ╠═3df77bf7-c364-4e27-bc06-a44d57d6db50
# ╠═667f1492-4549-48b7-83f7-792628135594
# ╠═0da5cc42-99e8-418c-95ca-93aa26c1e796
# ╠═2851f582-a3dc-48d2-b74a-8a2d013c9a43
# ╠═2b791542-ea24-42ac-87cb-c9dcc47a84a5
# ╠═b6dbb822-a951-42cd-a2f1-74e7cd79f250
# ╠═4e77e29f-80aa-48ae-a034-fe29d1d8dcd1
# ╠═58907d25-a0b5-431b-90be-259cae9bc6f1
# ╠═98d1cdda-0203-429c-9a27-de5605f04086
# ╠═056ec327-0108-4d19-a081-eb013af79ed9
# ╠═4f1297e0-9a1b-4f1a-917e-f36dbae1a95e
# ╠═12d5db00-8d44-48d5-ac94-6a067106c3fc
# ╠═812a3dbb-90dc-43a9-89ca-e38b88919057
# ╠═b48d27c0-501b-438a-b2e9-f150bcaf876e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
