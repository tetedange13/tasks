# MobiDL - tasks

MobiDL - tasks is a collection of tools wrapped in WDL to be used in any WDL pipelines.

## How to use ?

### Submodule

You can use this module as a submodule in another repository.

```bash
cd MyWorkflow
git submodule add git@github.com:MobiDL/tasks.git
git config --global diff.submodule log
git config status.submodulesummary 1
```

#### Update

```bash
git submodule update --remote tasks
```
<br>

## Testing

### Requirements

- [Pytest-workflow](https://github.com/LUMC/pytest-workflow)
- [Miniwdl](https://github.com/chanzuckerberg/miniwdl) (allow to precisely run a given task)


### Run tests

```bash
cd tasks

pytest --symlink --tag task_level --git-aware
```

### Details

A config file is passed to Miniwdl (= `sing.cfg`), it allows :
- To run it through a Singularity image (= Ubuntu 20.04)
- To ensure Singularity instance can access softs installed inside `Exome_prod` conda env (passing `PREPEND_PATH` special var)

### Dir organization

`test_a_task.yaml` files for each tested task are directly under `tests` sub-dir<br>
Test data for each task are expected to be under `tests/a_task`
