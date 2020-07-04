-- window objects --

local win = {}

function win:render()
  for x=self.x, self.w, 1 do
    for y=self.y, self.h, 1 do
      self.gpu.setForeground(self.fg[x][y])
      self.gpu.setBackground(self.bg[x][y])
      self.gpu.set(x,y,self.px[x][y])
    end
  end
end
