class CLI
  @@prompt = TTY::Prompt.new
  @@api = API.new

  def run
    puts "Hello!"
    @user = login
    main_menu
  end

  def login
    email = @@prompt.ask("Please enter your email address:")
    return User.find_by(email: email) if User.find_by(email: email)

    failure_message = "We couldn't find a user with that email address. Would you like to try again or register a new account?"
    response = @@prompt.select(failure_message, "Try again", "Register new account")
    response.eql?("Try again") ? login : register(email)
  end

  def register(email)
    name = @@prompt.ask("What should we call you?")
    User.create(name: name, email: email)
  end

  def main_menu
    refresh_user

    options = ["Search for a restaurant", "Review a restaurant"]
    options += ["Delete one of your reviews", "Update one of your reviews"] unless @user.reviews.empty?
    options << "Exit"
    selection = @@prompt.select("Hi #{@user.name}, how can we help you today?", options)
    menu_selection(selection)
  end

  def refresh_user
    @user = User.find(@user.id)
  end

  def menu_selection(selection)
    case selection
    when "Exit"
      puts "Thank you for using our app!"
    when "Search for a restaurant"
      search_for_restaurant
    when "Review a restaurant"
      review_restaurant
    when "Update a review"
      update_review
    when "Delete one of your reviews"
      delete_review
    when "Update one of your reviews"
      update_review
    end
  end

  def search_for_restaurant
    query = @@prompt.ask("What are you looking for?")
    restaurants = @@api.search_by_name(query)
    if restaurants
      restaurant = @@prompt.select("", restaurants)
      api_restaurant_action(restaurant)
    else
      puts "Sorry, no restaurants found for that query. Please try again."
      search_for_restaurant
    end
  end

  def api_restaurant_action(restaurant)
    location = restaurant["restaurant"]["location"]
    latitude = location["latitude"]
    longitude = location["longitude"]
    lat_long = latitude + "," + longitude

    choice = @@prompt.select("What would you like to do?", "Get directions", "Go back to main menu")
    choice.eql?("Get directions") ? get_directions(lat_long) : main_menu
  end

  def get_directions(lat_long)
    directions = @@api.direction_list(lat_long)
    puts ""
    directions.each do |direction|
      puts direction
    end
    puts ""
    @@prompt.select("", "Thanks")
    main_menu
  end

  def review_restaurant
    choice = choose_restaurant

    if choice.eql?("Add a new restaurant")
      new_restaurant = create_restaurant
      write_review(new_restaurant.name)
    else
      write_review(choice)
    end

    main_menu
  end

  def choose_restaurant
    @@prompt.select("x", Restaurant.random_names(10), "Add a new restaurant")
  end

  def create_restaurant
    Restaurant.create(name: @@prompt.ask("What is the restaurant called?"))
  end

  def write_review(restaurant_name)
    restaurant = Restaurant.find_by(name: restaurant_name)
    rating = @@prompt.slider("Rating", max: 5, min: 0, step: 0.5, default: 2.5, format: "|:slider| %.1f")
    content = @@prompt.ask("Please write a review:")

    Review.create(
      rating: rating,
      content: content,
      restaurant_id: restaurant.id,
      user_id: @user.id
    )
  end

  def update_review
    chosen_review = choose_user_review("Which review would you like to update?")
    chosen_review.rating = @@prompt.slider("Rating", max: 5, min: 0, step: 0.5, default: 2.5, format: "|:slider| %.1f")
    chosen_review.content = @@prompt.ask("Please write a new review:")
    chosen_review.save

    main_menu
  end

  def delete_review
    chosen_review = choose_user_review("Which review would you like to delete?")
    # add option to go back to main menu?
    confirm_message = "Are you sure you want to delete this review for #{chosen_review.restaurant.name}"
    if @@prompt.yes?(confirm_message)
      chosen_review.destroy
    end

    main_menu
  end

  def choose_user_review(message)
    # todo: two-step review choice (first choose restaurant, then choose review)
    @@prompt.select(message, @user.reviews_for_prompt)
  end
end
