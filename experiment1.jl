### A Pluto.jl notebook ###
# v0.18.0

using Markdown
using InteractiveUtils

# ╔═╡ c6c4c3c8-0627-45d6-9447-6e3df722fb06
begin
	using TOML
	using ReadableRegex
	using Pkg
	using Base: UUID, SHA1
	using Chain
	import Pkg.Versions: VersionRange
	import Pkg.Registry: VersionInfo
end

# ╔═╡ e23e539d-0cfc-48e0-92c0-a47e17411648
run(`git clone https://github.com/JuliaRegistries/General.git`)

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
pkg_info

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Chain = "8be319e6-bccf-4806-a6f7-6fae938471bc"
Pkg = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
ReadableRegex = "cbbcb084-453d-4c4c-b292-e315607ba6a4"
TOML = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[compat]
Chain = "~0.4.10"
ReadableRegex = "~0.3.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.8.0-beta1"
manifest_format = "2.0"
project_hash = "77812d0046a17db01ccf83f0a7d28254d2762444"

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

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

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

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.2.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.8.0"

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

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.12+1"

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
# ╠═e23e539d-0cfc-48e0-92c0-a47e17411648
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
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
