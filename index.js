process.env['PATH'] = process.env['PATH'] + ':' + process.env['LAMBDA_TASK_ROOT']

var exec = require('child_process').exec;
exports.handler = function(event, context) {
    var command = __dirname  + '/lib/ruby/bin/ruby' + ' -rbundler/setup ' + __dirname + '/lib/app/hello_world.rb'
    child = exec(command, {
        env: {'LD_LIBRARY_PATH': __dirname + '/lib',
              'BUNDLE_GEMFILE' : __dirname + '/lib/vendor/Gemfile'}
    }, function(error) {
        context.done(error, 'Process complete!');
    });
    child.stdout.on('data', console.log);
    child.stderr.on('data', console.error);
};
