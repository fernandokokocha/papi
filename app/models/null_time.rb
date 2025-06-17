class NullTime
  include Comparable

  def to_s
    ""
  end

  def to_i
    0
  end

  def to_datetime
    nil
  end

  def to_time
    nil
  end

  def strftime(_format)
    ""
  end

  def past?
    false
  end

  def future?
    false
  end

  def nil?
    false
  end

  def <=>(other)
    -1
  end

  def blank?
    true
  end
end
