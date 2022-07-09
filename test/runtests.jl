using PkgSwaps
using Test

@testset "PkgSwaps.jl" begin
    PkgSwaps.recommend(; project_toml_path=joinpath(@__DIR__, "../", "Project.toml"))
end
