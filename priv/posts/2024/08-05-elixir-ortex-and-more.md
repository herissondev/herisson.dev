%{
  title: "Running SAM model using Elixir and Ortex",
  author: "Aimé Risson",
  tags: ~w(Elixir Ortex Nx ONNX),
  description: "Running SAM (Segment Anything Model) on elixir with nx and ortex."
}
---

I'm currently working at this internship where some of the sales team spend a lot of time removing background form images using the very famous [removebg](https://www.remove.bg) website. Of course all of that is done manually and takes quite some time. (removebg does offer an api but it's expensive)

So I looked into what's possible and I found out about meta's [Segment Anything Model](https://github.com/facebookresearch/segment-anything) (SAM).

![SAM - select object example](/images/posts_images/sam_cover.png)

It's an image segmentation model that can take a bounding box as input to select the object within that box.  It can be used to produce a mask and once removed form the original image **boom** we have our own removebg.

As I had never worked with machine learning models in Elixir (or any other languages actually) I decided to give it a try.


This is my attempt into running [Segment Anything Model](https://github.com/facebookresearch/segment-anything) (SAM) from facebook research using the [Ortex](https://github.com/elixir-nx/ortex) library to run ONNX models.

Please note that this is my first time using Nx/Ortex/Onnx.

I'm more or less trying to port this jupyter notebook example to livebook: https://github.com/facebookresearch/segment-anything

I'm using onnx models found here: https://huggingface.co/vietanhdev/segment-anything-onnx-models/tree/main

```elixir
Nx.global_default_backend(EXLA.Backend)
Nx.default_backend()
```

## Loading the model

```elixir
model =
  Ortex.load("/Users/erisson/Documents/DEV/LEARNING/IA/SamOrtex/files/mobile_sam_encoder.onnx")
```

```elixir
decoder =
  Ortex.load("/Users/erisson/Documents/DEV/LEARNING/IA/SamOrtex/files/mobile_decoder.onnx")
```

## Image Encoding

1. resize to an 1024x1024 image
2. convert to tensor
3. Normalisze tensor
4. reshape to a (1, 3, 1024, 1024) tensor

```elixir
image_input = Kino.Input.image("Uploaded Image")
```

```elixir
%{file_ref: file_ref, format: :rgb, height: height, width: width} = Kino.Input.read(image_input)

content = file_ref |> Kino.Input.file_path() |> File.read!()

image_tensor =
  Nx.from_binary(content, :u8)
  |> Nx.reshape({height, width, 3})

resized_tensor = StbImage.resize()
# NxImage.resize(image_tensor, {1024, 1024})
# resized_tensor = NxImage.center_crop(image_tensor, {1024, 1024}, )
original_image = Kino.Image.new(image_tensor)
original_label = Kino.Markdown.new("**Original image**")

resized_image = Kino.Image.new(resized_tensor)
resized_label = Kino.Markdown.new("**Resized image**")

Kino.Layout.grid([
  Kino.Layout.grid([original_image, original_label], boxed: true),
  Kino.Layout.grid([resized_image, resized_label], boxed: true)
])
```

```elixir

```

```elixir
tensor =
  resized_tensor
  |> Nx.as_type(:f32)

# Mean and std values copied from transformer.js
mean = Nx.tensor([123.675, 116.28, 103.53])
std = Nx.tensor([58.395, 57.12, 57.375])

normalized_tensor =
  tensor
  |> NxImage.normalize(mean, std)

# taking +3s on my m1 mac ??
# setting up exla as the backend made it <20ms ?????

# Running image encoder
{image_embeddings} = Ortex.run(model, Nx.broadcast(normalized_tensor, {height, width, 3}))
```

## Prompt encoding & mask generation

```elixir
# prepare inputs
# xy coordinates in our image of the object we want to detour
input_point = Nx.tensor([[320, 240]]) |> Nx.as_type(:f32) |> Nx.reshape({1, 1, 2})

# 2, 3 is for box startig / end points
input_label = Nx.tensor([1]) |> Nx.reshape({1, 1}) |> Nx.as_type(:f32)

# Filled with 0, not used here
mask_input = Nx.broadcast(0, {1, 1, 256, 256}) |> Nx.as_type(:f32)

# not using mask_input
has_mask = Nx.broadcast(0, 1) |> Nx.as_type(:f32)

original_image_dim = Nx.tensor([height, width]) |> Nx.as_type(:f32)

{mask, _, _} =
  Ortex.run(decoder, {
    Nx.broadcast(image_embeddings, {1, 256, 64, 64}),
    Nx.broadcast(input_point, {1, 2, 2}),
    Nx.broadcast(input_label, {1, 2}),
    Nx.broadcast(mask_input, {1, 1, 256, 256}),
    Nx.broadcast(has_mask, {1}),
    Nx.broadcast(original_image_dim, {2})
  })
```

```elixir
mask =
  mask
  |> Nx.backend_transfer()
  |> Nx.map(fn x ->
    if Nx.to_number(x) >= 0 do
      255
    else
      0
    end
  end)

# na pas changer height/width
mask = mask[0][0] |> Nx.as_type(:u8) |> Nx.reshape({height, width, 1})
```

```elixir
resized_image = Kino.Image.new(mask)
resized_label = Kino.Markdown.new("**Image mask**")

Kino.Layout.grid([
  Kino.Layout.grid([original_image, original_label], boxed: true),
  Kino.Layout.grid([resized_image, resized_label], boxed: true)
])
```

```elixir
StbImage.from_nx(mask)
```
