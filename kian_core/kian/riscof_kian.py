import os
import re
import shutil
import subprocess
import shlex
import logging
import random
import string
from string import Template
import sys

import riscof.utils as utils
import riscof.constants as constants
from riscof.pluginTemplate import pluginTemplate

logger = logging.getLogger()

class kian(pluginTemplate):
    __model__ = "kian"

    __version__ = "XXX"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        config = kwargs.get('config')

        if config is None:
            print("Please enter input file paths in configuration.")
            raise SystemExit(1)

        self.dut_exe = os.path.join(config['PATH'] if 'PATH' in config else "","a.out") # TODO: confirm

        self.num_jobs = str(config['jobs'] if 'jobs' in config else 1)

        self.pluginpath=os.path.abspath(config['pluginpath'])

        self.isa_spec = os.path.abspath(config['ispec'])
        self.platform_spec = os.path.abspath(config['pspec'])

        if 'target_run' in config and config['target_run']=='0':
            self.target_run = False
        else:
            self.target_run = True

    def initialise(self, suite, work_dir, archtest_env):

        self.work_dir = work_dir
        self.suite_dir = suite

        self.compile_cmd = 'riscv{1}-unknown-elf-gcc -march={0} \
            -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -g\
            -T '+self.pluginpath+'/env/link.ld\
            -I '+self.pluginpath+'/env/\
            -I ' + archtest_env + ' {2} -o {3} {4}'

        self.extract_sig_start = "riscv{1}-unknown-elf-nm {2}/my.elf | grep begin_signature | awk '{print $1}'"
        self.extract_sig_end = "riscv{1}-unknown-elf-nm {2}/my.elf | grep end_signature | awk '{print $1}'"

        # add more utility snippets here
        build_kian = 'fusesoc run --target=verilator_tb --flag=mdu\
            --build --build-root=servant_test servant\
            --memsize=8388608 --compressed=1'
        utils.shellCommand(build_kian).run()

    def build(self, isa_yaml, platform_yaml):

      ispec = utils.load_yaml(isa_yaml)['hart0']

      self.xlen = ('64' if 64 in ispec['supported_xlen'] else '32')

      self.isa = 'rv' + self.xlen
      if "I" in ispec["ISA"]:
          self.isa += 'i'
      if "M" in ispec["ISA"]:
          self.isa += 'm'
      if "A" in ispec["ISA"]:
          self.isa += 'a'
      if "F" in ispec["ISA"]:
          self.isa += 'f'
      if "D" in ispec["ISA"]:
          self.isa += 'd'
      if "C" in ispec["ISA"]:
          self.isa += 'c'

      self.compile_cmd = self.compile_cmd+' -mabi='+('lp64 ' if 64 in ispec['supported_xlen'] else 'ilp32 ')

    def runTests(self, testList):

      if os.path.exists(self.work_dir+ "/Makefile." + self.name[:-1]):
            os.remove(self.work_dir+ "/Makefile." + self.name[:-1])
      # create an instance the makeUtil class that we will use to create targets.
      make = utils.makeUtil(makefilePath=os.path.join(self.work_dir, "Makefile." + self.name[:-1]))

      make.makeCommand = 'make -k -j' + self.num_jobs

      for testname in testList:

          testentry = testList[testname]

          test = testentry['test_path']

          test_dir = testentry['work_dir']

          elf = 'my.elf'

          # name of the signature file as per requirement of RISCOF. RISCOF expects the signature to
          # be named as DUT-<dut-name>.signature. The below variable creates an absolute path of
          # signature file.
          sig_file = os.path.join(test_dir, self.name[:-1] + ".signature")
          sig_start = int(subprocess.check_output(self.extract_sig_start, shell=True, text=True).strip(), 16)
          sig_end   = int(subprocess.check_output(self.extract_sig_end, shell=True, text=True).strip(), 16)


          # for each test there are specific compile macros that need to be enabled. The macros in
          # the testList node only contain the macros/values. For the gcc toolchain we need to
          # prefix with "-D". The following does precisely that.
          compile_macros= ' -D' + " -D".join(testentry['macros'])

          # substitute all variables in the compile command that we created in the initialize
          # function
          cmd = self.compile_cmd.format(testentry['isa'].lower(), self.xlen, test, elf, compile_macros)

	  # if the user wants to disable running the tests and only compile the tests, then
	  # the "else" clause is executed below assigning the sim command to simple no action
	  # echo statement.
          if self.target_run:
            # set up the simulation command. Template is for spike. Please change.
            simcmd = self.dut_exe + ' +signature={1} +sig_start={2} +sig_end={3} +firmware={4}'.format(sig_file, sig_start, sig_end, elf)
          else:
            simcmd = 'echo "NO RUN"'

          # concatenate all commands that need to be executed within a make-target.
          execute = '@cd {0}; {1}; {2};'.format(testentry['work_dir'], cmd, simcmd)

          # create a target. The makeutil will create a target with the name "TARGET<num>" where num
          # starts from 0 and increments automatically for each new target that is added
          make.add_target(execute)

      # if you would like to exit the framework once the makefile generation is complete uncomment the
      # following line. Note this will prevent any signature checking or report generation.
      #raise SystemExit

      # once the make-targets are done and the makefile has been created, run all the targets in
      # parallel using the make command set above.
      make.execute_all(self.work_dir)

      # if target runs are not required then we simply exit as this point after running all
      # the makefile targets.
      if not self.target_run:
          raise SystemExit(0)

#The following is an alternate template that can be used instead of the above.
#The following template only uses shell commands to compile and run the tests.

#    def runTests(self, testList):
#
#      # we will iterate over each entry in the testList. Each entry node will be referred to by the
#      # variable testname.
#      for testname in testList:
#
#          logger.debug('Running Test: {0} on DUT'.format(testname))
#          # for each testname we get all its fields (as described by the testList format)
#          testentry = testList[testname]
#
#          # we capture the path to the assembly file of this test
#          test = testentry['test_path']
#
#          # capture the directory where the artifacts of this test will be dumped/created.
#          test_dir = testentry['work_dir']
#
#          # name of the elf file after compilation of the test
#          elf = 'my.elf'
#
#          # name of the signature file as per requirement of RISCOF. RISCOF expects the signature to
#          # be named as DUT-<dut-name>.signature. The below variable creates an absolute path of
#          # signature file.
#          sig_file = os.path.join(test_dir, self.name[:-1] + ".signature")
#
#          # for each test there are specific compile macros that need to be enabled. The macros in
#          # the testList node only contain the macros/values. For the gcc toolchain we need to
#          # prefix with "-D". The following does precisely that.
#          compile_macros= ' -D' + " -D".join(testentry['macros'])
#
#          # collect the march string required for the compiler
#          marchstr = testentry['isa'].lower()
#
#          # substitute all variables in the compile command that we created in the initialize
#          # function
#          cmd = self.compile_cmd.format(marchstr, self.xlen, test, elf, compile_macros)
#
#          # just a simple logger statement that shows up on the terminal
#          logger.debug('Compiling test: ' + test)
#
#          # the following command spawns a process to run the compile command. Note here, we are
#          # changing the directory for this command to that pointed by test_dir. If you would like
#          # the artifacts to be dumped else where change the test_dir variable to the path of your
#          # choice.
#          utils.shellCommand(cmd).run(cwd=test_dir)
#
#          # for debug purposes if you would like stop the DUT plugin after compilation, you can
#          # comment out the lines below and raise a SystemExit
#
#          if self.target_run:
#            # build the command for running the elf on the DUT. In this case we use spike and indicate
#            # the isa arg that we parsed in the build stage, elf filename and signature filename.
#            # Template is for spike. Please change for your DUT
#            execute = self.dut_exe + ' --isa={0} +signature={1} +signature-granularity=4 {2}'.format(self.isa, sig_file, elf)
#            logger.debug('Executing on Spike ' + execute)
#
#          # launch the execute command. Change the test_dir if required.
#          utils.shellCommand(execute).run(cwd=test_dir)
#
#          # post-processing steps can be added here in the template below
#          #postprocess = 'mv {0} temp.sig'.format(sig_file)'
#          #utils.shellCommand(postprocess).run(cwd=test_dir)
#
#      # if target runs are not required then we simply exit as this point after running all
#      # the makefile targets.
#      if not self.target_run:
#          raise SystemExit
