{ Generics regression cases; original case IDs are retained below. }

{ Case tw20577a.pp }
{$push}
{$mode delphi}{$H+}

type

  tw20577a_tsimplehashbucket<T> = record
     tw20577a_hashcode : Integer;
     tw20577a_value : T;
  end;

  tw20577a_tsimplehashbucketarray<T> = array of tw20577a_tsimplehashbucket<T>;

  { TSimpleHash }

  tw20577a_tsimplehash<T> = class
    private
    tw20577a_fbuckets : tw20577a_tsimplehashbucketarray<T>;
  procedure tw20577a_test;
  end;

{ TSimpleHash<T> }

procedure tw20577a_tsimplehash<T>.tw20577a_test;
var
  tw20577a_oldbuckets : tw20577a_tsimplehashbucketarray<T>;
begin
  tw20577a_oldbuckets := tw20577a_fbuckets;

end;
{$pop}

{ Case tw20577b.pp }
{$push}
{$mode delphi}{$H+}

type

  tw20577b_tsimplehashbucket<T> = record
     tw20577b_hashcode : Integer;
     tw20577b_value : T;
  end;

  tw20577b_tsimplehashbucketarray<T> = array of tw20577b_tsimplehashbucket<T>;

  { TSimpleHash }

  tw20577b_tsimplehash<T> = class
  private
    type
      tw20577b_thashbucket = tw20577b_tsimplehashbucket<T>;
    var
      tw20577b_fbuckets: array of tw20577b_thashbucket;
  procedure tw20577b_test;
  end;

{ TSimpleHash<T> }

procedure tw20577b_tsimplehash<T>.tw20577b_test;
var
  tw20577b_oldbuckets : tw20577b_tsimplehashbucketarray<T>;
begin
  tw20577b_oldbuckets := tw20577b_fbuckets;

end;
{$pop}

begin
end.
