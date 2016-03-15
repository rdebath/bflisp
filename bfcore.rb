#!/usr/bin/env ruby

require './common'

class BFCore
  def initialize(g)
    @g = g
  end

  def gen_prologue(data)
    g = @g

    g.comment('interpreter check')

    # Test for cell wrap != 256
    g.emit '>[-]<[-]++++++++[>++++++++<-]>[<++++>-]<[>>'

    # Print message 'Sorry this program needs an 8bit interpreter\n'
    g.emit '>++++[<++++>-]<+[>++++++>+++++++>++>+++>+++++<<<<<-]>>>>>--.<<<-'
    g.emit '-------.+++..+++++++.>--.<-----.<++.+.>-.>.<---.++.---.<--.>+++.'
    g.emit '<------.>-----.>.<+.<++++..-.>+++++.>.<<---.>-----.>.>+++++.<<<+'
    g.emit '.>-----.+++++++++++.>.<<+++++++.+++++.>.<---------.>--.--.++.<.>'
    g.emit '++.<.>--.<<++++++++++.'

    # endif
    g.emit '<<[-]]'

    # Test for cell wrap != 256 and flip condition
    g.emit '>[-]<[-]++++++++[>++++++++<-]>[<++++>-]+<[>-<[-]]>[-<'

    g.comment('init data')
    data.each do |d, i|
      raise if i > 65535
      hi = i / 256
      lo = i % 256
      ptr = MEM + MEM_BLK_LEN * hi + MEM_CTL_LEN + lo * (BITS / 8)
      g.add_word(ptr, d)
    end

    g.comment('prologue')
    g.add(RUNNING, 1)
    g.emit '['
    #g.emit '@'
  end

  def gen_core
    g = @g

    gen_mem_load
    gen_mem_store

    g.move_word(NPC, PC)
  end

  def gen_mem_load
    g = @g
    g.comment 'memory (load)'

    g.decloop(LOAD_REQ) {
      g.move_ptr(MEM)
      g.set_ptr(0)

      g.move(MEM_A, MEM_CH)
      g.move(MEM_A+1, MEM_CL)

      g.move_ptr(MEM_ZN)

      # LOAD
      # Z   Z   CL  CH  RL  RH  D1  D2  MEMORY
      g.emit '>>>[->+>+<<]>[-<+>]<<[->>+<<<+>]<[->+<]>[<<+>>[-<+>]]<[->+<]>>[<'
      g.emit '<<+>>>[-<<+>>]]<<[->>+<<]<[[-]+>>[<<->>[-<+>]]<[->+<]<[->>>-<<<]'
      g.emit '>>->>>>>>[-<<<<<<<<+>>>>>>>>]>[-<<<<<<<<+>>>>>>>>]<<[->>+<<]<[->'
      g.emit '>+<<]<[->>+<<]<[->>+<<]<[->>+<<]<[->>+<<]>>[<<+>>[-<+>]]<[->+<]>'
      g.emit '>[<<<+>>>[-<<+>>]]<<[->>+<<]<]>>>>>>[-]>[-]>[-<+<+>>]<[->+<]>>[-'
      g.emit '<<+<<<<+>>>>>>]<<<<<<[->>>>>>+<<<<<<]>[<<+>>[-<+>]]<[->+<]>>[<<<'
      g.emit '+>>>[-<<+>>]]<<[->>+<<]<[[-]+>>[<<->>[-<+>]]<[->+<]<[->>>-<<<]>>'
      g.emit '-<<[-<<+>>]>[-<<+>>]>[-<<+>>]>[-<<+>>]>[-<<+>>]>[-<<+>>]<<<<<<<<'
      g.emit '[->>>>>>>>+<<<<<<<<]<[->>>>>>>>+<<<<<<<<]>>>>[<<+>>[-<+>]]<[->+<'
      g.emit ']>>[<<<+>>>[-<<+>>]]<<[->>+<<]<]<<'

      g.move(MEM_D1, MEM_V)
      g.move(MEM_D2, MEM_V+1)

      g.move_ptr(0)
      g.set_ptr(MEM)
      g.clear_word(A)
      g.move_word(MEM + MEM_V, A)
    }
  end

  def gen_mem_store
    g = @g
    g.comment 'memory (store)'

    g.decloop(STORE_REQ) {
      g.move_ptr(MEM)
      g.set_ptr(0)


      g.move(MEM_A, MEM_CH)
      g.move(MEM_A+1, MEM_CL)

      g.move(MEM_V, MEM_D1)
      g.move(MEM_V+1, MEM_D2)

      g.move_ptr(MEM_ZN)

      # STORE
      # Z   Z   CL  CH  RL  RH  D1  D2  MEMORY
      g.emit '>>>[->+>+<<]>[-<+>]<<[->>+<<<+>]<[->+<]>[<<+>>[-<+>]]<[->+<]>>[<'
      g.emit '<<+>>>[-<<+>>]]<<[->>+<<]<[[-]+>>[<<->>[-<+>]]<[->+<]<[->>>-<<<]'
      g.emit '>>->>>>>>[-<<<<<<<<+>>>>>>>>]>[-<<<<<<<<+>>>>>>>>]<<[->>+<<]<[->'
      g.emit '>+<<]<[->>+<<]<[->>+<<]<[->>+<<]<[->>+<<]>>[<<+>>[-<+>]]<[->+<]>'
      g.emit '>[<<<+>>>[-<<+>>]]<<[->>+<<]<]>>>>>>>>[-]<<[->>+<<]>>>[-]<<[->>+'
      g.emit '<<]<<<[<<+>>[-<+>]]<[->+<]>>[<<<+>>>[-<<+>>]]<<[->>+<<]<[[-]+>>['
      g.emit '<<->>[-<+>]]<[->+<]<[->>>-<<<]>>-<<[-<<+>>]>[-<<+>>]>[-<<+>>]>[-'
      g.emit '<<+>>]>[-<<+>>]>[-<<+>>]<<<<<<<<[->>>>>>>>+<<<<<<<<]<[->>>>>>>>+'
      g.emit '<<<<<<<<]>>>>[<<+>>[-<+>]]<[->+<]>>[<<<+>>>[-<<+>>]]<<[->>+<<]<]'
      g.emit '<<'

      g.move_ptr(0)
      g.set_ptr(MEM)
    }
  end

  def gen_epilogue
    g = @g
    g.comment('epilogue')
    g.move_ptr(RUNNING)
    g.emit ']'

    # endif for cell size check. (should be [-]] but we already have a zero)
    g.emit ']'
    # EOL at EOF
    g.comment('[...THE END...]')
  end

end

if __FILE__ == $0
  require './bfasm'
  require './bfgen'

  bfa = BFAsm.new
  code, data = bfa.parse(File.read(ARGV[0]))

  g = BFGen.new
  bfc = BFCore.new(g)
  bfc.gen_prologue(data)
  bfa.emit(g)
  bfc.gen_core
  bfc.gen_epilogue
end
