//
//  ViewController.swift
//  Filters
//
//  Created by Joshua Homann on 1/24/20.
//  Copyright © 2020 com.josh. All rights reserved.
//

import UIKit
import MetalKit
import AVFoundation

class ViewController: UIViewController {
  @IBOutlet var metalView: MTKView! {
    didSet {
      metalView.delegate = self
      metalView.device = device
      metalView.framebufferOnly = false
      metalView.enableSetNeedsDisplay = true
    }
  }

  private let device: MTLDevice
  private let commandQueue: MTLCommandQueue
  private let context: CIContext
  private let colorSpace = CGColorSpaceCreateDeviceRGB()
  private var ciImage: CIImage?

  required init?(coder: NSCoder) {
    guard let device = MTLCreateSystemDefaultDevice(),
      let commandQueue = device.makeCommandQueue() else {
        return nil
    }
    self.device = device
    self.commandQueue = commandQueue
    context = CIContext(mtlDevice: device)
    super.init(coder: coder)

  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard let blur = CIFilter(name: "CIGaussianBlur"),
      let scaleFilter = CIFilter(name: "CILanczosScaleTransform"),
      let originalImage = UIImage(named: "aurora"),
      let inputImage = originalImage.cgImage.flatMap(CIImage.init(cgImage:)) else {
      return
    }
    let imageWidth = originalImage.size.width
    let imageHeight = originalImage.size.height
    let aspectRatio = 1
    let scale = max(
      metalView.bounds.size.width * UIScreen.main.nativeScale / imageWidth,
      metalView.bounds.size.height * UIScreen.main.nativeScale / imageHeight
    )
    scaleFilter.setValue(inputImage, forKey: kCIInputImageKey)
    scaleFilter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
    scaleFilter.setValue(scale, forKey: kCIInputScaleKey)

    blur.setValue(scaleFilter.outputImage, forKey: kCIInputImageKey)
    blur.setValue(14.0, forKey: kCIInputRadiusKey)
    guard let blurredImage = blur.outputImage else {
      return
    }
    let cropRect = CGRect(origin: .zero, size: .init(
      width: scale * imageWidth,
      height: scale * imageHeight)
    )
    ciImage = blurredImage
      .cropped(to: cropRect)
      .transformed(by: .init(scaleX: 1, y: -1))
  }
}

extension ViewController: MTKViewDelegate {
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    view.setNeedsDisplay()
  }

  func draw(in view: MTKView) {
    guard let currentDrawable = view.currentDrawable,
      let image = ciImage,
      let commandBuffer = commandQueue.makeCommandBuffer()
    else {
      return
    }

    context.render(
     image,
     to: currentDrawable.texture,
     commandBuffer: commandBuffer,
     bounds: image.extent
      .offsetBy(
        dx: -(view.bounds.size.width * UIScreen.main.nativeScale - image.extent.size.width) / 2,
        dy: -(view.bounds.size.height * UIScreen.main.nativeScale - image.extent.size.height) / 2
      ),
     colorSpace: colorSpace
    )

    commandBuffer.present(currentDrawable)
    commandBuffer.commit()
  }
}
