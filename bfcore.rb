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
      hi = i / 256
      lo = i % 256
      ptr = MEM + MEM_BLK_LEN * (1+hi) + MEM_CTL_LEN + lo * 2
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

    g.move_ptr(LOAD_REQ)
    g.emit '[-'
    g.move_ptr(MEM)
    g.set_ptr(0)

    g.move_ptr(MEM_A)
    g.emit '+['
    g.move_word(MEM_A, MEM_A + MEM_BLK_LEN)
    g.move_ptr(MEM_A + MEM_BLK_LEN)
    g.set_ptr(MEM_A)
    g.add(MEM_WRK, 1)
    g.move_ptr(MEM_A)
    g.emit '-]'

    256.times{|al|
      g.move_ptr(MEM_A + 1)
      g.ifzero(1) do
        g.copy_word(MEM_CTL_LEN + al * 2, MEM_V, MEM_WRK + 2)
      end
      g.add(MEM_A + 1, -1)
    }
    g.clear(MEM_A + 1)
    g.move_ptr(MEM_WRK)
    g.emit '[-'
    g.move_word(MEM_V, MEM_V - MEM_BLK_LEN)
    g.move_ptr(MEM_V - MEM_BLK_LEN)
    g.set_ptr(MEM_V)
    g.move_ptr(MEM_WRK)
    g.emit ']'

    g.move_ptr(0)
    g.set_ptr(MEM)
    g.clear_word(A)
    g.move_word(MEM + MEM_V, A)
    g.move_ptr(LOAD_REQ)

    g.emit ']'
  end

  def gen_mem_store
    g = @g
    g.comment 'memory (store)'

    g.move_ptr(STORE_REQ)
    g.emit '[-'
    g.move_ptr(MEM)
    g.set_ptr(0)

    g.move_ptr(MEM_A)
    g.emit '+['
    g.move_word(MEM_V, MEM_V + MEM_BLK_LEN)
    g.move_word(MEM_A, MEM_A + MEM_BLK_LEN)
    g.move_ptr(MEM_A + MEM_BLK_LEN)
    g.set_ptr(MEM_A)
    g.add(MEM_WRK, 1)
    g.move_ptr(MEM_A)
    g.emit '-]'

    # VH VL 0 AL 1
    256.times{|al|
      g.move_ptr(MEM_A + 1)
      g.ifzero(1) do
        g.clear_word(MEM_CTL_LEN + al * 2)
        g.move_word(MEM_V, MEM_CTL_LEN + al * 2)
      end
      g.add(MEM_A + 1, -1)
    }
    g.clear(MEM_A + 1)
    g.move_ptr(MEM_WRK)
    g.emit '[-' + '<' * MEM_BLK_LEN + ']'

    g.move_ptr(0)
    g.set_ptr(MEM)
    g.move_ptr(STORE_REQ)
    g.emit ']'
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
