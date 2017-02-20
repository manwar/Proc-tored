package Proc::tored;
# ABSTRACT: Service management using a pid file and touch files

use strict;
use warnings;
require Exporter;
require Proc::tored::Manager;

=head1 SYNOPSIS

  use Proc::tored;

  my $service = service 'stuff-doer', in '/var/run';

  # Run service
  run { do_stuff() } $service
    or die 'existing process running under pid '
          . running $service;

  # Pause and resume a running process
  if (paused $service) {
    do_stuff_while_paused();
    resume $service;
  }
  else {
    pause $service;
    do_stuff_while_paused();
    resume $service;
  }

  # Terminate a running process, timing out after 15s
  zap $service, 15
    or die 'stuff_doer pid ' . running $service . ' is being stubborn';

=head1 DESCRIPTION

A C<Proc::tored> service is voluntarily managed by a pid file and touch files.

=head1 PID FILES

A pid file is used to identify a running service. While the service is running,
barring any outside interference, the pid will contain the pid of the running
process and a newline. After the service process stops, the pid file will be
truncated. The file will be located in the directory specified by L</in>. Its
name will be the concatenation of the service name and ".pid".

=head1 STATE FLAGS

State flags are persistent until unset. Their status is determined by the
existence of a touch file.

=head2 stopped

=head2 paused

=head1 EXPORTED SUBROUTINES

All routines are exported by default.

=head2 service

=head2 in

A proctored service is defined using the C<service> function. The name given to
the service is used in the naming of various files used to control the service
(e.g., pid file and touch files). The C<in> function is used to specify the
local directory where these files will be created and looked for.

  my $service = service 'name-of-service', in '/var/run';

=head2 pid

Reads and returns the contents of the pid file. Does not check to determine
whether the pid is valid. Returns 0 if the pid file is not found or is empty.

  printf "service may be running under pid %d", pid $service;

=head2 running

Reads and returns the contents of the pid file. Essentially the same as
C<kill(0, pid $service)>. Returns 0 if the pid is not found or cannot be
signalled.

  if (my $pid = running $service) {
    warn "service is already running under pid $pid";
  }

=head2 run

Begins the service in the current process. The service, specified as a code
block, will be called until it returns false or the L</stopped> flag is set.

If the L</paused> flag is set, the loop will continue to run without executing
the code block until it has been L</resume>d.

  my $started = time;
  my $max_run_time = 300;

  run {
    if (time - $started > $max_run_time) {
      warn "Max run time ($max_run_time seconds) exceeded\n";
      warn "  -shutting down\n";
      return 0;
    }
    else {
      do_some_work();
    }

    return 1;
  } $service;

=head2 zap

Sets the "stopped" flag (see L</stop>), then blocks until a running service
exits. Returns immediately (after setting the "stopped" flag) if the
L</running> service is the current process.

  sub stop_service {
    if (my $pid = running $service) {
      print "Attempting to stop running service running under process $pid\n";

      if (zap $pid, 30) {
        print "  -Service shut down\n";
        return 1;
      }
      else {
        print "  -Timed out before service shut down\n";
        return 0;
      }
    }
  }

=head2 stop

=head2 start

=head2 stopped

Controls and inspects the "stopped" flag for the service.

  # Stop a running service
  if (!stopped $service && running $service) {
    stop $service;
  }

  do_work_while_stopped();

  # Allow service to start
  # Note that this does not launch the service process. It simply clears the
  # "stopped" flag that would have prevented it from running again.
  start $service;

=head2 pause

=head2 resume

=head2 paused

Controls and inspects the "paused" flag for the service.

  # Pause a running service
  # Note that the running service will not exit. Instead, it will stop
  # executing its main loop until the "paused" flag is cleared.
  if (!paused $service && running $service) {
    pause $service;
  }

  do_work_while_paused();

  # Allow service to resume execution
  resume $service;

=cut

use parent 'Exporter';

our @EXPORT = qw(
  service
  in

  pid
  running
  zap
  run

  stop
  start
  stopped

  pause
  resume
  paused
);

sub service ($%)  { Proc::tored::Manager->new(name => shift, @_) }
sub in      ($;@) { dir => shift, @_ }

sub pid     ($)   { $_[0]->read_pid }
sub running ($)   { $_[0]->running_pid }
sub zap     ($;@) { shift->stop_wait(@_) }
sub run     (&$)  { $_[1]->service($_[0]) }

sub stop    ($)   { $_[0]->stop }
sub start   ($)   { $_[0]->start }
sub stopped ($)   { $_[0]->is_stopped }

sub pause   ($)   { $_[0]->pause }
sub resume  ($)   { $_[0]->resume }
sub paused  ($)   { $_[0]->is_paused }

1;
