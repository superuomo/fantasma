#!/usr/bin/env ruby

# TODO: disable images, plugins, extensions in the browser,
# parallelize using watirgrid

# Headless. See: https://github.com/leonid-shevtsov/headless
# requires xorg-server-xvfb
#require 'rubygems'
#require 'headless'
#headless = Headless.new
#headless.start

#DEBUG:
#require 'pp'
#then use:
# pp var

#require 'rubygems'
#require 'watir'
#b = Watir::Browser.new :firefox

# Use Selenium webdriver (probably slower, but works).
#require 'watir-webdriver'
#b = Watir::Browser.new :firefox

# Selenium webdriver with Chrome.
# You need to install package chromedriver or:
# https://code.google.com/p/chromedriver/downloads/list
require 'watir-webdriver'
b = Watir::Browser.new :chrome

# To use HTML Unit with jruby (unfortunately our JavaScript is not well
# supported):
#require 'rubygems'
#require 'celerity'
#b = Celerity::Browser.new

require 'csv'

# Return a random number between low and high (both inclusive).
def self.rand_range(low, high)
  rand(high+1-low)+low
end

# DEBUG: count requests
#$c=0
def pause(reduced_wait=false)
  # DEBUG: count requests
  #$c=$c+1
  #puts $c

=begin
Wait from 8 to 20 sec. Since the average number of requests is 22,
that is there are 21 pauses between requests, this equates to sessions
lasting on average between 3 and 7 minutes.
=end
  #sleep reduced_wait ? rand_range(4, 10) : rand_range(8, 20)
  sleep 5
end

=begin
We could download this data from geonames.org, but we won't be sure they
all yield at least one search result. So I have extracted them from our
database like so:
root@supp2:~# su - postgres
postgres@supp2:~$ psql dowant_live_de
dowant_live_de=# Copy (SELECT split_part(split_part(address_cache, ',', 2), ' ',
2) AS postcode, split_part(address_cache, ',', 1) AS address FROM
restaurant_restaurant WHERE split_part(split_part(address_cache, ',', 2), ' ',
2) IS NOT NULL AND split_part(address_cache, ',', 1) IS NOT NULL AND
split_part(split_part(address_cache, ',', 2), ' ',
2) != '' AND split_part(address_cache, ',', 1) != '') TO
'/tmp/de_postcodes_list.csv' With DELIMITER '|';
COPY 13445

I then used shaf to randomize the file better.
=end
$reader = CSV.open('de_postcodes_list.csv','r')

def next_place
  row = $reader.shift
  if row.empty?
    $reader.rewind    
    row = reader.shift
  end
  return row
end

# Sample inspection commands:
# puts Watir::HTMLElement.instance_methods(false)
# puts Watir::Anchor.instance_methods(false)

b.goto 'http://www.lieferheld.de'
place = next_place
b.text_field(:id, 'strasse').set place[1]
b.text_field(:id, 'zipcode_or_city').set place[0]

pause

# when_present decorator only needed if there is no pause before
b.element(:css, '.green_big.submit').click

# Select a random restaurant,
first = true
# DEBUG:
#1.times do
rand_range(2, 3).times do
  pause

  unless first
    b.back
  else
    first = false
  end

=begin
  I cannot use: b.elements(:css => '.restaurant_link.restaurant-open')
  b/c :css is only supported on element(s) and it returns only
  Watir::HTMLElement (missing the href method), but :class is supported on any
  tag. I will not select restaurant-open, because there could not be any
  (e.g. if test is run before 11am).
=end
  link = b.links(:class, 'restaurant_link')

  pause

  b.goto link[rand(link.length)].href
end

pause

i = 0
cat = 0
# Basket minimum 5 items or as much as you need to place an order.
while i < 5 or b.div(:id, 'cart_btn_order').attribute_value('class').scan('button_inactive') == 'button_inactive'
  # Select random category.
  cats = b.div(:id, 'menu_category_list').uls
  subcats = cats[rand(cats.length)].lis
  randcat = rand(subcats.length)
  subcat = subcats[randcat]
  # Found category id, needed to be sure to not try to basket
  # items from collapsed categories, b/c it won't work.
  # Example id: menu_category_selector_207045
  catid = subcat.attribute_value('id').rpartition('_')[2]
  # Do not click on first category (Alle anzeigen - all offers),
  # which is selected by default.
  # DISABLED b/c it does not always work
  #if randcat != cat
    subcat.when_present.click
  #DEBUG:
  #else
  #  puts "randcat: #{randcat}, cat: #{cat}, not clicked"
  #end
  cat = randcat
  
  pause
  
  # Basket random disk.
  # instead of lis, you can also try spans(:class, 'price_bg')
  # or divs(:class, 'item_text')
  if catid == 'top10'
    items = b.div(:class, 'top10Center').lis
    # DEBUG:
    #puts "top10"
  elsif catid == 'all'
    items = b.div(:id, 'menu_list').uls
    items = items[rand(items.length)].lis
    # DEBUG
    #puts "all"
  else
    items = b.div(:id, "menu_section-#{catid}").lis
    # DEBUG:
    #puts "menu_section-#{catid}"
  end
  items[rand(items.length)].when_present.click

  pause

  popup = b.div(:id, 'flavor_lightbox')
  if not popup.attribute_value('style').match /display: none;$/
    # DEBUG:
    #puts "POPUP detected"
    
    # The structure of the ingredient list is slightly different depending if its
    # Radiobutton or checkboxes
  
    popup.forms(:class, 'jqtransformdone').each do |form|
      # Do NOT click or set the radio button but rather the empty anchor before!
      if form.link(:class, 'jqTransformCheckbox').exists?
        # Checkbox case.
        # DEBUG:
        # puts "checkbox exists"
        form.link(:class, 'jqTransformCheckbox').click
        # DEBUG:
        # puts "checkbox set"
        pause true
      elsif form.link(:class, 'jqTransformRadio').exists?
        # Radiobutton case.
        # DEBUG:
        # puts "radiobox exists"
        form.link(:class, 'jqTransformRadio').click
        # DEBUG:
        # puts "radiobox set"
        pause true
      end
    end
  
    # Click on confirmation button.
    popup.link(:class, 'add buttonSecondary').when_present.click

    pause
  end

  i = i + 1
end

pause

# Click on the checkout link
b.link(:id, 'cartDummyButton').click
