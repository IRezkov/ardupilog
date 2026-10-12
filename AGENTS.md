# MATLAB source conventions

- Keep scripts such as `plot2.m` as scripts; do not define local functions inside them.
- Put each function in its own `.m` file under `functions/`, and add it to `log_analyzer.prj` when it is needed by the standalone application.
