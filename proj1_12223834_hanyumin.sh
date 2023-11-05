#!/bin/bash

NAME="한유민"
STUDENT_ID="12223834"

echo "이름: $NAME"
echo "학생 번호: $STUDENT_ID"

DATA_FILE="/c/oss/u.data"
ITEM_FILE="/c/oss/u.item"
USER_FILE="/c/oss/u.user"

# 특정 'movie id'에 해당하는 영화 데이터를 가져오는 함수
get_movie_data() {
  grep "^$1|" "$ITEM_FILE"
}

# 액션 장르 영화 데이터를 가져오는 함수
get_action_movies() {
  read -p "Do you want to get the data of 'action' genre movies from 'u.item'? (y/n): " yn
  if [[ $yn == [Yy] ]]; then
    awk -F'|' '$7 == "1" {print $1, $2}' "$ITEM_FILE" | sort -n | head -n 10
  else
    echo "Action genre movies will not be displayed."
  fi
}



# 특정 'movie id'의 영화 평균 'rating'을 구하는 함수

get_average_rating() {
  awk -F'\t' -v movie_id="$1" '
  $2 == movie_id {ratings_sum += $3; ratings_count++}
  END {
    if (ratings_count > 0) {
      printf "average rating of %d: %.5f\n", movie_id, (int((ratings_sum / ratings_count) * 1e6 + 0.5) / 1e6)
    } else {
      print "No ratings found."
    }
  }' "$DATA_FILE"
}

# ‘IMDb URL’을 삭제하는 함수
delete_imdb_url() {
  read -p "Do you want to delete the 'IMDb URL' from 'u.item'? (y/n): " yn
  if [[ $yn == [Yy] ]]; then
    # IMDb URL 필드($5)를 공백으로 대체하고 나머지 필드는 그대로 출력합니다.
    awk -F'|' 'BEGIN {OFS=FS} {$5=""; print}' "$ITEM_FILE" | head -n 10
    echo "IMDb URL has been deleted from the displayed output."
  else
    echo "IMDb URL deletion was cancelled."
  fi
}

get_user_data() {
  read -p "Do you want to get the data about users from 'u.user'? (y/n): " yn
  if [[ $yn == [Yy] ]]; then
    awk -F'|' '{printf "user %s is %s years old %s %s\n", $1, $2, $3, $4}' "$USER_FILE" | head -n 10
  else
    echo "User data retrieval was cancelled."
  fi
}

# 'release date' 형식을 수정하는 함수
modify_release_date() {
  read -p "Do you want to modify the format of 'release date' in 'u.item'? (y/n): " yn
  if [[ $yn == [Yy] ]]; then
    awk -F'|' 'BEGIN {
      OFS=FS;  # 출력 필드 구분자를 입력 필드 구분자와 동일하게 설정합니다.
      # 월 이름을 숫자로 매핑합니다.
      months["Jan"] = "01"; months["Feb"] = "02"; months["Mar"] = "03";
      months["Apr"] = "04"; months["May"] = "05"; months["Jun"] = "06";
      months["Jul"] = "07"; months["Aug"] = "08"; months["Sep"] = "09";
      months["Oct"] = "10"; months["Nov"] = "11"; months["Dec"] = "12";
    }
    {
      # 날짜 필드($3)를 '-'로 분할합니다.
      split($3, date_parts, "-");
      # 날짜 부분이 3개로 분할된 경우에만 변환을 수행합니다.
      if (length(date_parts) == 3) {
        # 변환된 날짜 형식을 YYYYMMDD로 설정합니다.
        $3 = date_parts[3] months[date_parts[2]] date_parts[1];
      }
      print;
    }' "$ITEM_FILE" | tail -n 10
    echo "Release date format has been modified."
  else
    echo "Modification cancelled."
  fi
}

# 특정 'user id'가 평가한 영화 데이터를 가져오는 함수
get_movies_rated_by_user() {
  # 사용자 ID 입력을 요청합니다.
  read -p "Please enter the 'user id' (1~943): " user_id
  printf "\n"
  awk -F'\t' -v user_id="$user_id" '$1 == user_id {print $2}' "$DATA_FILE" | sort -n | uniq | tr '\n' '|' | sed 's/|$//'
  echo -e "\n"

  awk -F'\t' -v user_id="$user_id" '$1 == user_id {print $2}' "$DATA_FILE" | sort -n | uniq | head -10 | while read movie_id; do
    awk -F'|' -v movie_id="$movie_id" '$1 == movie_id {print $1 "|" $2}' "$ITEM_FILE"
  done
}

# 20세에서 29세 사이의 'age'를 가진 'programmer' 직업을 가진 사용자들이 평가한 영화의 평균 'rating'을 구하는 함수
get_average_rating_programmers() {
  read -p "Do you want to get the average 'rating' of movies rated by users with 'age' between 20 and 29 and 'occupation' as 'programmer'? (y/n): " yn
  if [[ $yn == [Yy] ]]; then
    # 먼저 'programmer' 직업을 가진 20~29세 사이의 사용자 ID를 모읍니다.
    programmers=$(awk -F'|' '$2 >= 20 && $2 <= 29 && $4 ~ /programmer/' "$USER_FILE" | cut -d'|' -f1)
    if [ -z "$programmers" ]; then
      echo "No programmers in the specified age range found."
      return
    fi

    # 사용자 ID 리스트를 임시 파일에 저장합니다.
    temp_file=$(mktemp)
    echo "$programmers" > "$temp_file"

    # 각 영화에 대한 모든 평점을 합산합니다.
    awk -F'\t' 'NR==FNR {progs[$1]; next} $1 in progs {ratings[$2]+=$3; counts[$2]++} 
    END {
      for (i in ratings) {
        if (counts[i] > 0) {
          avg = ratings[i]/counts[i]
          if (avg == int(avg)) {
           printf ("%d %d\n", i, avg)
          } else {
           printf("%d %.5f\n", i, avg)
          }
        }
      }
    }' "$temp_file" "$DATA_FILE" | sort -k1,1n
    
    # 임시 파일을 삭제합니다.
    rm "$temp_file"
  else
    echo "Average rating retrieval cancelled."
  fi
}

# 메인 메뉴 루프
while true; do
  echo "Name: $NAME"
  echo "Student ID: $STUDENT_ID"
  echo "--------------------------"
  echo "[ Menu ]"
  echo "1. Get the data of the movie identified by a specific 'movie id' from 'u.item'"
  echo "2. Get the data of action genre movies from 'u.item'"
  echo "3. Calculate the average 'rating' of the movie identified by a specific 'movie id' from 'u.data'"
  echo "4. Delete the 'IMDb URL' from 'u.item'"
  echo "5. Get the data about users from 'u.user'"
  echo "6. Modify the format of 'release date' in 'u.item'"
  echo "7. Get the data of movies rated by a specific 'user id' from 'u.data'"
  echo "8. Calculate the average 'rating' of movies rated by users with 'age' between 20 and 29 and 'occupation' as 'programmer'"
  echo "9. Exit"
  echo "--------------------------"
  read -p "Enter your choice [ 1-9 ] " choice

  case $choice in
    1)
      read -p "Enter movie ID: " movie_id
      get_movie_data "$movie_id"
      ;;
    2)
      get_action_movies
      ;;
    3)
      read -p "Enter movie ID: " movie_id
      get_average_rating "$movie_id"
      ;;
    4)
      delete_imdb_url
      ;;
    5)
      get_user_data
      ;;
    6)
      modify_release_date
      ;;
    7)
      get_movies_rated_by_user
      ;;
    8)
      get_average_rating_programmers
      ;;
    9)
      echo "Bye!"
      exit 0
      ;;
    *)
      echo "Invalid option, please try again."
      ;;
  esac 
done
