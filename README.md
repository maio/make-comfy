# make-comfy - verify commit

## Installation

First you need to add make-comfy into your project. E.g., via subtree:

```
git subtree add --prefix=env/dev/make-comfy --squash git@github.com:maio/make-comfy.git master
```

Then create Makefile in the repository root:

```
include env/dev/make-comfy/src/MakeComfy.mk

.PHONY: lint test

VERIFY = lint test

lint:
	eslint src

test:
	npm test
```

Link/copy `make-comfy/src/git-post-commit-hook` into `.git/hooks/post-commit`.
