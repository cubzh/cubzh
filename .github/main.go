package main

import (
	"github.com/cubzh/cubzh/.github/internal/dagger"
)

type Github struct{}

// Generate the github actions config files
func (m *Github) Generate() *dagger.Directory {
	return dag.Gha(dagger.GhaOpts{
		DaggerVersion: "latest",
		// Public tokens have restricted privileges,
		// they are a workaround to Github Action's restrictions
		// on secret access in public forks
		PublicToken: "p.eyJ1IjogIjFiZjEwMmRjLWYyZmQtNDVhNi1iNzM1LTgxNzI1NGFkZDU2ZiIsICJpZCI6ICI4ZmZmNmZkMi05MDhiLTQ4YTEtOGQ2Zi1iZWEyNGRkNzk4MTkifQ.l1Sf1gB37veXUWhxOgmjvjYcrh32NiuovbMxvjVI7Z0",
	}).
		WithPipeline(
			"Lua Modules (linter)",
			"lint-modules --src=.:modules",
			dagger.GhaWithPipelineOpts{
				OnPullRequestBranches: []string{"main"},
				SparseCheckout: []string{
					"lua",
				},
			},
		).
		WithPipeline(
			"Core Unit Tests",
			"test-core --src=.:test-core",
			dagger.GhaWithPipelineOpts{
				OnPullRequestBranches: []string{"main"},
				Lfs:                   true,
				SparseCheckout: []string{
					"core",
					"deps/libz",
				},
			}).
		WithPipeline(
			"Core clang-format",
			"lint-core --src=.:lint-core",
			dagger.GhaWithPipelineOpts{
				OnPullRequestBranches: []string{"main"},
				Lfs:                   true,
				SparseCheckout: []string{
					"core",
					"deps/libz",
				},
			}).
		Config().
		Directory(".github")
}
