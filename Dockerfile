FROM ruby:2.3
RUN apt-get update && apt-get install -y \
    imagemagick \
    postgresql-client \
    libpq-dev \
    inkscape \
    rrdtool \
    librrd4 \
    librrd-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/* && mkdir /usr/src/app
WORKDIR /usr/src/app
COPY Gemfile Gemfile.lock /usr/src/app/
RUN bundle install
COPY . /usr/src/app
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]