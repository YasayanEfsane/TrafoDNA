%RUN_TESTS Convenience script for the complete TrafoDNA test suite.
projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));
testResults = runAllTests(); %#ok<NASGU>
