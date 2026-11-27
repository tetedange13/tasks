## Testing

### Requirements

- [Pytest-workflow](https://github.com/LUMC/pytest-workflow)
- [MiniWDL](https://github.com/chanzuckerberg/miniwdl)
- Cromwell (womtool to validate syntax)

<br>

### Run tests

```bash
pytest \
	--keep-workflow-wd \
	--verbose \
	--git-aware \
	--basetemp=/path/to/anotherdir/ \
	tests/
```

WARNING: '/path/to/anotherdir' must exist on each node of cluster

Due to `--keep-workflow-wd` option, dirs `Name_of_my_test` present at `--basetemp` path (created by `pytest-workflow`) must be be deleted *manually* afterwards
